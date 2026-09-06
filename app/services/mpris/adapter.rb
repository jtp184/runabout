require "dbus"

module Mpris
  class Adapter
    INTERFACE = "org.mpris.MediaPlayer2.Player"
    PROPERTIES = "org.freedesktop.DBus.Properties"
    PREFIX = "org.mpris.MediaPlayer2."

    def initialize
      @bus = DBus::ASessionBus.new
      @objects = {}
      @dirty = true
      @bus.proxy.on_signal("NameOwnerChanged") do |name, _old, _new|
        if name.start_with?(PREFIX)
          unsubscribe(name)
          @dirty = true
        end
      end
    rescue NotImplementedError => error
      raise IOError, error.message
    end

    def snapshot
      names = @bus.proxy.ListNames.first.grep(/\Aorg\.mpris\.MediaPlayer2\./)
      (@objects.keys - names).each { |name| unsubscribe(name) }
      names.each_with_object({}) do |name, players|
        begin
          players[name] = object(name)[PROPERTIES].GetAll(INTERFACE).first
        rescue DBus::Error
          unsubscribe(name)
        end
      end
    ensure
      @dirty = false
    end

    def wait(timeout = 0.25)
      @bus.dispatch_message_queue
      if IO.select([ @bus.message_queue.socket ], nil, nil, timeout)
        @bus.dispatch_message_queue
      end
      @dirty
    end

    def execute(command)
      player = object(command.bus_name)[INTERFACE]
      case command.action
      when "SetPosition"
        player.SetPosition(DBus::ObjectPath.new(command.track_id), (command.value * 1_000_000).to_i)
      when "Volume"
        player["Volume"] = command.value
      else
        player.public_send(command.action)
      end
    end

    def close
      @bus.message_queue.socket.close
    end

    private

    def object(name)
      @objects[name] ||= begin
        proxy = @bus.service(name).object("/org/mpris/MediaPlayer2")
        proxy.introspect
        proxy[PROPERTIES].on_signal("PropertiesChanged") { |interface, _changed, _invalidated| @dirty = true if interface == INTERFACE }
        proxy[INTERFACE].on_signal("Seeked") { |_position| @dirty = true }
        proxy
      end
    end

    def unsubscribe(name)
      proxy = @objects.delete(name)
      return unless proxy
      proxy[PROPERTIES].on_signal("PropertiesChanged")
      proxy[INTERFACE].on_signal("Seeked")
    end
  end
end
