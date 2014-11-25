module Services
  class BaseFinder < Services::Base
    disable_call_logging

    def call(ids = [], conditions = {})
      ids, conditions = Array(ids), conditions.symbolize_keys
      special_conditions = conditions.extract!(:order, :limit, :page, :per_page)

      object_table_id = "#{object_class.table_name}.id"

      scope = object_class.public_send(Rails::VERSION::MAJOR == 3 ? :scoped : :all)
      scope = scope.where(object_table_id => ids) unless ids.empty?

      unless conditions.empty?
        scope = scope
          .select("DISTINCT #{object_table_id}")
          .order(object_table_id)
        scope = process(scope, conditions)
        scope = object_class.where(id: scope)
      end

      special_conditions.each do |k, v|
        case k
        when :order
          order = if v == 'random'
            'RANDOM()'
          else
            "#{object_class.table_name}.#{v}"
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
