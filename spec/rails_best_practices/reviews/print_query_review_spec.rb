require 'spec_helper'

module RailsBestPractices
  module Reviews
    describe PrintQueryReview do
      let(:runner) { Core::Runner.new(reviews: PrintQueryReview.new) }

      before :each do
        content = <<-EOF
        class User < ActiveRecord::Base
          has_many :projects
          belongs_to :location
          validates :username, uniqueness: {scope: :account}
          scope :loads, ->(ids) {joins(:projects).where(projects: {id: ids}).distinct}
        end
        EOF
        runner.prepare('app/models/user.rb', content)

        content = <<-EOF
        class Post < ActiveRecord::Base
          has_many :comments
          validates :length, uniqueness: {scope: :parent_id}
        end
        class Comment < ActiveRecord::Base
        end
        EOF
        runner.prepare('app/models/post.rb', content)
      end
      
      it 'should return query chain' do
        content = <<-EOF
        class User < ActiveRecord::Base
          has_many :projects
          belongs_to :location
          scope :loads, lambda { preload(:projects) }
          def test
            self.loads(ids).joins(:location)
          end
        end
        EOF
        runner.review('app/models/user.rb', content)
        expect(runner.errors.size).to eq(1)
        expect(runner.errors[0].to_s).to eq('app/model.user.rb:6 - query chain')
      end

      it 'should return query chain' do
        content = <<-EOF
        class PostsController < ApplicationController
          def index
            @post = Post.order('id').where('parent_id=?', params[:parent_id])
            @post.comments.where('length>?', params[:length])
            @p = Post.where("LOWER(name) = ?", params['id'].downcase).first
          end
        end
        EOF
        runner.review('app/controllers/posts_controller.rb', content)
        expect(runner.errors.size).to eq(1)
        expect(runner.errors[0].to_s).to eq('app/controllers/posts_controller.rb:3 - query chain')
      end
    end
  end
end