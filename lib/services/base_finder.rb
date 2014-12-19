module Services
  class BaseFinder < Services::Base
    disable_call_logging

    def call(ids = [], conditions = {})
      ids, conditions = Array(ids), conditions.symbolize_keys
      object_table_id = "#{object_class.table_name}.id"

      special_conditions = conditions.extract!(:order, :limit, :page, :per_page)
      special_conditions[:order] = object_table_id unless special_conditions.has_key?(:order)

      scope = object_class.public_send(Rails::VERSION::MAJOR == 3 ? :scoped : :all)
      scope = scope.where(object_table_id => ids) unless ids.empty?

      unless conditions.empty?
        scope = process(scope, conditions)
        scope = object_class.where(id: scope.select("DISTINCT #{object_table_id}"))
      end

      special_conditions.each do |k, v|
        case k
        when :order
          next unless v
          order = case v
          when 'random' then 'RANDOM()'
          when /\./     then v
          else               "#{object_class.table_name}.#{v}"
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
