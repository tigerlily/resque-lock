module Resque
  module Plugins
    # If you want only one instance of your job queued at a time,
    # extend it with this module.
    #
    # For example:
    #
    # require 'resque/plugins/lock'
    #
    # class UpdateNetworkGraph
    #   extend Resque::Plugins::Lock
    #
    #   def self.perform(repo_id)
    #     heavy_lifting
    #   end
    # end
    #
    # No other UpdateNetworkGraph jobs will be placed on the queue,
    # the QueueLock class will check Redis to see if any others are
    # queued with the same arguments before queueing. If another
    # is queued the enqueue will be aborted.
    #
    # If you want to define the key yourself you can override the
    # `lock` class method in your subclass, e.g.
    #
    # class UpdateNetworkGraph
    #   extend Resque::Plugins::Lock
    #
    #   # Run only one at a time, regardless of repo_id.
    #   def self.lock(repo_id)
    #     "network-graph"
    #   end
    #
    #   def self.perform(repo_id)
    #     heavy_lifting
    #   end
    # end
    #
    # The above modification will ensure only one job of class
    # UpdateNetworkGraph is running at a time, regardless of the
    # repo_id. Normally a job is locked using a combination of its
    # class name and arguments.
    module Lock
      # Override in your job to control the lock key. It is
      # passed the same arguments as `perform`, that is, your job's
      # payload.
      def lock(*args)
        "lock:#{name}-#{args.to_s}"
      end

      # Override in your job to control the lock key TTL. If `nil`
      # it will not expire (which is the default behavior).
      def lock_ttl(*args)
        nil
      end

      def before_enqueue_lock(*args)
        lock_key = lock(*args)
        lock_key_ttl = lock_ttl(*args)
        if Resque.redis.setnx(lock_key, true)
          # Set TTL if specified and enqueue job
          Resque.redis.expire(lock_key, lock_key_ttl) unless lock_key_ttl.nil?
          return true
        else
          # Do not enqueue job
          return false
        end
      end

      def around_perform_lock(*args)
        begin
          yield
        ensure
          # Always clear the lock when we're done, even if there is an
          # error.
          Resque.redis.del(lock(*args))
        end
      end
    end
  end
end

