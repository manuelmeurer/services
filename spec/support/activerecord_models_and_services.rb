require 'active_record'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

ActiveRecord::Schema.define do
  create_table :posts, force: true do |t|
    t.string :title
    t.text :body
  end

  create_table :comments, force: true do |t|
    t.string :body
    t.references :post
  end
end

class Post < ActiveRecord::Base
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

module Services
  module Posts
    class FindRaiseConditions < Services::Query
      convert_condition_objects_to_ids :comment

      private

      def process(scope, conditions)
        raise conditions.to_json
      end
    end
  end
end

module Services
  module Posts
    class Find < Services::Query
      convert_condition_objects_to_ids :comment

      private

      def process(scope, conditions)
        conditions.each do |k, v|
          case k
          when :title, :body
            scope = scope.where(k => v)
          when :comment_id
            scope = scope.joins(:comments).where("#{Comment.table_name}.id" => v)
          else
            raise ArgumentError, "Unexpected condition: #{k}"
          end
        end
        scope
      end
    end
  end
end

module Services
  module Comments
    class Find < Services::Query
      convert_condition_objects_to_ids :post

      private

      def process(scope, conditions)
        conditions.each do |k, v|
          case k
          when :body, :post_id
            scope = scope.where(k => v)
          else
            raise ArgumentError, "Unexpected condition: #{k}"
          end
        end
        scope
      end
    end
  end
end
