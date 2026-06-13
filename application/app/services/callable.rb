# Tiny `.call` convenience used by producers and the service:
# `Foo.call(args)` is shorthand for `Foo.new(args).call`.
module Callable
  extend ActiveSupport::Concern

  class_methods do
    def call(*args, **kwargs, &block)
      new(*args, **kwargs, &block).call
    end
  end
end
