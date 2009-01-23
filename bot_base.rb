#!/usr/bin/env ruby

require 'rubygems'
require 'xmpp4r'
require 'xmpp4r/roster'
require 'yaml'

class BotBase
  
  def initialize(username, password, status="I am a bot")
    @commands = {}
    
    @friends_sent_to = []
    @friends_online = {}
    @state = nil
    @mainthread = Thread.current
    @itunes = OSA.app('itunes')
    @ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
    @last_message = nil
    
    load_commands
    
    login(username, password)

    listen_for_subscription_requests
    listen_for_messages

    send_initial_presence(status)

    Thread.stop
  end
  
  def Command(value, &proc)
    @commands[value] = proc
  end
  
  def load_commands
    begin
      Dir['commands/*.rb'].each do |command|
        file = ""
        File.open(command, "r") do |infile|
          while (line = infile.gets)
              file << line
          end
        end
        instance_eval file
      end
    rescue StandardError => e
      "#{e.message}"
    end
  end

  def login(username, password)
    @jid    = Jabber::JID.new(username)
    @client = Jabber::Client.new(@jid)
    @client.connect
    @client.auth(password)
  end
  
  def escape(input)
    @ic.iconv(input)
  end 
  
  def logout
    @mainthread.wakeup
    @client.close
  end

  def send_initial_presence(status)
    @client.send(Jabber::Presence.new.set_status(status))
  end

  def listen_for_subscription_requests
    @roster   = Jabber::Roster::Helper.new(@client)

    @roster.add_subscription_request_callback do |item, pres|
      if pres.from.domain == @jid.domain
        log "ACCEPTING AUTHORIZATION REQUEST FROM: " + pres.from.to_s
        @roster.accept_subscription(pres.from)
      end
    end
  end
  
  def send_message_to(incoming, outgoing)
    msg      = Jabber::Message.new(incoming.from, escape( outgoing ))
    msg.type = :chat
    @client.send(msg)
  end
  
  def reload_commands(m)
    @commands = {}
    output = load_commands
    send_message_to(m, "#{output} #{@commands.inspect}")
  end

  def listen_for_messages
    @client.add_message_callback do |m|
      if m.type != :error && @state == nil
        if !@friends_sent_to.include?(m.from)
          send_message_to(m, "Hello. I am robot. You are connecting for the first time.")
          @friends_sent_to << m.from
        end
        if m.body == 'reload!'
          self.reload_commands(m)
        else
          send_message_to(m, response_to( m.body ) )
        end
      end
    end
  end
  
  def listen_for_presence_notifications
    @client.add_presence_callback do |m|
      case m.type
      when nil # status: available
        log "PRESENCE: #{m.from.to_short_s} is online"
        @friends_online[m.from.to_short_s] = true
      when :unavailable
        log "PRESENCE: #{m.from.to_short_s} is offline"
        @friends_online[m.from.to_short_s] = false
      end
    end
  end

  def log(message)
    puts(message) if Jabber::debug
  end
  
  def response_to(value)
    result = "I don't know how you respond to that :-( "
    @commands.each do |k,proc|
      regexp = case(k)
      when String
        Regexp.new("^#{k}$", Regexp::IGNORECASE)
      when Regexp
        k
      else
        raise "Commands must be Regexp or String!!!"
      end
      matches = regexp.match(value)
      begin
        result = proc.call(matches.to_a[1..-1]) unless matches.nil?
      rescue StandardError => e
        result = e.message
      end
    end
    result
  end
  
end
