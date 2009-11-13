module Merb
  module GlobalHelpers
    # helpers defined here available to all views.  
    def markaby(&block)
      Markaby::Builder.new({}, self, &block)
    end
  end
end
