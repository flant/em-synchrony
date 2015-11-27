require 'em-synchrony'

ActiveSupport.on_load(:active_record) do
  class ActiveRecord::Base
    class StatementCache < Hash
      include Mutex_m

      def fiber_mutex
        @fiber_mutex ||= EventMachine::Synchrony::Thread::Mutex.new
      end

      def synchronize_with_fiber_mutex(*a, &blk)
        fiber_mutex.synchronize do
          synchronize_without_fiber_mutex(*a, &blk)
        end
      end

      alias_method_chain :synchronize, :fiber_mutex
    end

    class << self
      def define_attribute_methods_with_fiber_mutex
        @attribute_methods_fiber_mutex ||= EventMachine::Synchrony::Thread::Mutex.new

        @attribute_methods_fiber_mutex.synchronize do
          define_attribute_methods_without_fiber_mutex
        end
      end

      alias_method_chain :define_attribute_methods, :fiber_mutex

      def initialize_find_by_cache
        self.find_by_statement_cache = StatementCache.new
      end
    end
  end

  class ActiveRecord::ConnectionAdapters::ConnectionPool
    include EventMachine::Synchrony::MonitorMixin

    def current_connection_id #:nodoc:
      ActiveRecord::Base.connection_id ||= Fiber.current.object_id
    end

    def clear_stale_cached_connections!
      []
    end
  end

  class ActiveRecord::ConnectionAdapters::AbstractAdapter
    include EventMachine::Synchrony::MonitorMixin

    def lease
      synchronize do
        unless in_use?
          @owner = Fiber.current
        end
      end
    end
  end
end
