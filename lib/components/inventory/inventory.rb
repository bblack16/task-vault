require_relative 'item'
require 'securerandom'

module TaskVault
  class Inventory < ServerComponent
    attr_ary_of Item, :items, default: [], serialize: true
    attr_int :interval, default: 60, serialize: true
    attr_int :capacity, default: 1000, allow_nil: true, serialize: true
    attr_int :access_counter, default: 0, serialize: false

    def start
      queue_info('Starting up component.')
      super
    end

    def stop
      queue_info('Stopping component.')
      super
    end

    def self.description
      'You make it, I store it. Inventory is a shared object store for all of the components running in a server.'
    end

    def size
      items.size
    end

    def percent
      return 0 unless capacity
      (size / capacity.to_f * 100).round
    end

    def has?(qry)
      !find(qry).nil?
    end

    def find(qry)
      find_item(qry)&.value
    end

    def find_item(qry)
      self.access_counter += 1
      return store(qry) if qry.is_a?(Item)
      items.find do |i|
        if qry.is_a?(Hash)
          i.fits?(qry)
        else
          i.key.to_s == qry.to_s
        end
      end
    end

    def find_all(qry)
      find_all_items(qry).map(&:value)
    end

    def find_all_items(qry)
      self.access_counter += 1
      items.find_all do |i|
        if qry.is_a?(Hash)
          i.fits?(qry)
        else
          i.key == qry
        end
      end
    end

    def store(args)
      item = find(args) unless args.is_a?(Item)
      return item if item
      _add_item(args.is_a?(Item) ? args : Item.new(args))
    end

    alias add store

    def clean_expired
      number = items.inject(0) do |sum, item|
        if item.expired?
          items.delete(item)
          sum += 1
        end
        sum
      end
      queue_info("Cleaned out #{number} expired item#{number == 1 ? nil : 's'}.") unless number.zero?
    end

    def clean_capacity
      return unless capacity && items.size > capacity
      overage = items.size - capacity
      queue_info("Inventory is over capcity by #{overage} item#{overage == 1 ? nil : 's'}. Cleaning by access time.")
      sorted = items.sort_by(&:last_accessed)
      until items.size <= capacity
        item = sorted.shift
        queue_debug("Deleting item #{item.key} (#{item.value.class}). Last accessed at #{item.last_accessed}.")
        items.delete(item)
      end
    end

    protected

    def simple_init(*args)
      super
      require_relative 'api'
    end

    def run
      loop do
        queue_debug("Inventory is currently at #{items.size} item#{items.size == 1 ? nil : 's'} (#{percent}% full) and has been accessed #{access_counter} time#{access_counter == 1 ? nil : 's'}.")
        clean_expired
        clean_capacity
        sleep(interval)
      end
    rescue StandardError => e
      queue_fatal(e)
    end

    def _add_item(item)
      return item if items.include?(item)
      queue_debug("Adding new item to inventory (#{item.value.class} - #{item.key}).")
      items << item
      clean_capacity
      item
    end

  end

end
