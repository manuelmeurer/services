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

      def process(scope, condition, value)
        if condition == :comment_id
          raise({ condition => value }.to_json)
        end
      end
    end
  end
end

module Services
  module Posts
    class Find < Services::Query
      convert_condition_objects_to_ids :comment

      private

      def process(scope, condition, value)
        case condition
        when :title, :body
          scope.where(condition => value)
        when :comment_id
          scope.joins(:comments).where("#{Comment.table_name}.id" => value)
        end
      end
    end
  end
end

module Services
  module Comments
    class Find < Services::Query
      convert_condition_objects_to_ids :post

      private

      def process(scope, condition, value)
        case condition
        when :body, :post_id
          scope.where(condition => value)
        end
      end
    end
  end
end
