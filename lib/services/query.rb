module Services
  class Query
    include ObjectClass

    class << self
      delegate :call, to: :new

      def convert_condition_objects_to_ids(*class_names)
        @object_to_id_class_names = class_names
      end

      def object_to_id_class_names
        @object_to_id_class_names || []
      end
    end

    def call(ids_or_conditions = {}, _conditions = {})
      ids, conditions = if ids_or_conditions.is_a?(Hash)
        if _conditions.any?
          fail ArgumentError, 'If conditions are passed as first argument, there must not be a second argument.'
        end
        [[], ids_or_conditions.symbolize_keys]
      else
        if ids_or_conditions.nil?
          fail ArgumentError, 'IDs must not be nil.'
        end
        [Array(ids_or_conditions), _conditions.symbolize_keys]
      end

      object_table_id = "#{object_class.table_name}.id"

      special_conditions = conditions.extract!(:id_not, :order, :limit, :page, :per_page)
      special_conditions[:order] = object_table_id unless special_conditions.has_key?(:order)

      scope = conditions.delete(:scope).try(:dup) || object_class.public_send(ActiveRecord::VERSION::MAJOR == 3 ? :scoped : :all)
      scope = scope.where(object_table_id => ids) unless ids.empty?

      unless conditions.empty?
        self.class.object_to_id_class_names.each do |class_name|
          if object_or_objects = conditions.delete(class_name)
            ids = case object_or_objects
            when Array
              object_or_objects.map(&:id)
            when ActiveRecord::Relation
              object_or_objects.pluck(:id)
            else
              [object_or_objects.id]
            end
            conditions[:"#{class_name}_id"] = ids.size == 1 ? ids.first : ids
          end
        end

        scope = process(scope, conditions)

        # If a JOIN is involved, use a subquery to make sure we're getting DISTINCT records.
        if scope.to_sql =~ / join /i
          scope = object_class.where(id: scope.select("DISTINCT #{object_table_id}"))
        end
      end

      special_conditions.each do |k, v|
        case k
        when :id_not
          scope = scope.where.not(id: v)
        when :order
          next unless v
          case v
          when 'random'
            order = 'RANDOM()'
          when /\A([A-Za-z0-9_]+)\./
            table_name = $1
            unless table_name == object_class.table_name
              unless reflection = object_class.reflections.values.detect { |reflection| reflection.table_name == table_name }
                fail "Reflection on class #{object_class} with table name #{table_name} not found."
              end
              # TODO: In Rails 5, we can use #left_outer_joins
              # http://blog.bigbinary.com/2016/03/24/support-for-left-outer-joins-in-rails-5.html
              join_conditions = "LEFT OUTER JOIN #{table_name} ON #{table_name}.#{reflection.foreign_key} = #{object_class.table_name}.id"
              if reflection.type
                join_conditions << " AND #{table_name}.#{reflection.type} = '#{object_class}'"
              end
              scope = scope.joins(join_conditions)
            end
            order = v
          else
            order = "#{object_class.table_name}.#{v}"
          end
          scope = scope.order(order)
        when :limit
          scope = scope.limit(v)
        when :page
          scope = scope.page(v)
        when :per_page
          scope = scope.per(v)
        else
          raise ArgumentError, "Unexpected special condition: #{k}"
        end
      end

      scope
    end
  end
end
