module Services
  class Query
    include ObjectClass

    COMMA_REGEX                = /\s*,\s*/
    TABLE_NAME_REGEX           = /\A([A-Za-z0-9_]+)\./
    CREATED_BEFORE_AFTER_REGEX = /\Acreated_(before|after)\z/

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

      unless conditions.key?(:order)
        conditions[:order] = object_table_id
      end

      scope = conditions.delete(:scope).try(:dup) || object_class.all
      if ids.any?
        scope = scope.where(object_table_id => ids)
      end

      if conditions.any?
        self.class.object_to_id_class_names.each do |class_name|
          if object_or_objects = conditions.delete(class_name)
            ids = case object_or_objects
            when Array
              object_or_objects.map(&:id)
            when ActiveRecord::Relation
              object_or_objects.select(:id)
            else
              [object_or_objects.id]
            end
            conditions[:"#{class_name}_id"] = ids.size == 1 ? ids.first : ids
          end
        end

        conditions.each do |k, v|
          if new_scope = process(scope, k, v)
            conditions.delete k
            scope = new_scope
          end
        end

        # If a JOIN is involved, use a subquery to make sure we get DISTINCT records.
        if scope.to_sql =~ / join /i
          scope = object_class.where(id: scope.select("DISTINCT #{object_table_id}"))
        end
      end

      conditions.each do |k, v|
        case k
        when :id_not
          scope = scope.where.not(id: v)
        when CREATED_BEFORE_AFTER_REGEX
          operator = $1 == 'before' ? '<' : '>'
          scope = scope.where("#{object_class.table_name}.created_at #{operator} ?", v)
        when :order
          next unless v

          order = v.split(COMMA_REGEX).map do |order_part|
            table_name = order_part[TABLE_NAME_REGEX, 1]
            case
            when table_name && table_name != object_class.table_name
              unless reflection = object_class.reflections.values.detect { |reflection| reflection.table_name == table_name }
                fail "Reflection on class #{object_class} with table name #{table_name} not found."
              end

              if ActiveRecord::VERSION::MAJOR >= 5
                scope = scope.left_outer_joins(reflection.name)
              else
                join_conditions = "LEFT OUTER JOIN #{table_name} ON #{table_name}.#{reflection.foreign_key} = #{object_class.table_name}.id"
                if reflection.type
                  join_conditions << " AND #{table_name}.#{reflection.type} = '#{object_class}'"
                end
                scope = scope.joins(join_conditions)
              end
            when !table_name
              order_part.prepend "#{object_class.table_name}."
            end
            order_part
          end.join(', ')

          scope = scope.order(order)
        when :limit
          scope = scope.limit(v)
        when :page
          scope = scope.page(v)
        when :per_page
          scope = scope.per(v)
        else
          raise ArgumentError, "Unexpected condition: #{k}"
        end
      end

      scope
    end
  end
end
