require 'em-synchrony'

module EventMachine::Synchrony::ActiveRecord
  module Core
    extend ActiveSupport::Concern

    class StatementCache < Hash
      include Mutex_m

      def fiber_mutex
        @fiber_mutex ||= ::EventMachine::Synchrony::Thread::Mutex.new
      end

      def synchronize_with_fiber_mutex(*a, &blk)
        fiber_mutex.synchronize do
          synchronize_without_fiber_mutex(*a, &blk)
        end # synchronize
      end

      alias_method_chain :synchronize, :fiber_mutex
    end # StatementCache

    module ClassMethods
      def initialize_find_by_cache
        self.find_by_statement_cache = ::EventMachine::Synchrony::ActiveRecord::Core::StatementCache.new
      end
    end # ClassMethods
  end # Core

  module AttributeMethods
    extend ActiveSupport::Concern

    included do
      class << self
        alias_method_chain :define_attribute_methods, :fiber_mutex
      end # << self
    end # included

    module ClassMethods
      def attribute_methods_fiber_mutex
        @attribute_methods_fiber_mutex ||= ::EventMachine::Synchrony::Thread::Mutex.new
      end

      def define_attribute_methods_with_fiber_mutex
        attribute_methods_fiber_mutex.synchronize do
          define_attribute_methods_without_fiber_mutex
        end
      end
    end # ClassMethods
  end # AttributeMethods

  module ConnectionAdapters
    module ConnectionPool
      def current_connection_id #:nodoc:
        ::ActiveRecord::Base.connection_id ||= Fiber.current.object_id
      end

      def clear_stale_cached_connections!
        []
      end
    end # ConnectionPool
  end # ConnectionAdapters
end # EventMachine::Synchrony::ActiveRecord

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.send(:include, EventMachine::Synchrony::ActiveRecord::Core)
  ActiveRecord::Base.send(:include, EventMachine::Synchrony::ActiveRecord::AttributeMethods)

  ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, EventMachine::Synchrony::MonitorMixin)

  ActiveRecord::ConnectionAdapters::ConnectionPool.send(:include, EventMachine::Synchrony::MonitorMixin)
  ActiveRecord::ConnectionAdapters::ConnectionPool.send(:include,
      EventMachine::Synchrony::ActiveRecord::ConnectionAdapters::ConnectionPool)
end
