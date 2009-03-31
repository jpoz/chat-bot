#!/usr/bin/env ruby

require 'rubygems'
require 'xmpp4r'
require 'xmpp4r/roster'
require 'xmpp4r/muc'
require 'yaml'

class BotBase
  
  def initialize(username, password, status="I am a bot", host=nil)
    @commands = {}
    
    @friends_sent_to = [@jid]
    @friends_online = {}
    @state = nil
    @mainthread = Thread.current
    @ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
    @last_message = nil
    @jid    = Jabber::JID.new(username)
    @subscribers = [@jid]
    
    load_commands
    
    login(password, host)

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

  def login(password, host = nil)
    @client = Jabber::Client.new(@jid)
    @client.connect(host)
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
  
  def send_message_to(from, outgoing)
    msg      = Jabber::Message.new(from, escape( outgoing ))
    msg.type = :chat
    @client.send(msg)
  end
  
  def reload_commands(m)
    @commands = {}
    output = load_commands
    send_message_to(m.from, "#{output} #{@commands.inspect}")
  end

  def listen_for_messages
    @client.add_message_callback do |m|
      if m.type != :error && @state == nil
        if !@friends_sent_to.include?(m.from)
          send_message_to(m.from, "Hello I'm a chatroom bot. If you'd like to enter my room say '!enter!'.")
          @friends_sent_to << m.from
        elsif /^\!(.*)\!$/.match(m.body)
          run_command($1, m)
        elsif @subscribers.include?(m.from)
          send_group_chat(m)
        else
          send_message_to(m.from, "You need to enter the room to chat. Say '!enter!' to enter the room.")
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
  
  def run_command(text, m)
    if text == 'reload'
      self.reload_commands(m)
    elsif text == 'enter'
      if !@subscribers.include?(m.from)
        send_message_to(m.from, "Welcome to this chat room. If you'd like to leave say '!leave!' ")
        send_group_chat(m, "#{m.from.node} has entered")
        @subscribers << m.from
      else
        send_message_to(m.from, "You're already in this room :-)")
      end
    elsif text == 'leave'
      @subscribers.delete(m.from)
      send_group_chat(m, "#{m.from.node} has left.")
      send_message_to(m.from, "You have left the chat room.")
    else
      send_message_to(m.from, response_to( text ) )
    end
  end
  
  def send_group_chat(m, text = nil)
    message = text ? text : "#{m.from.node}: #{m.body}"
    @subscribers.each do |f|
      unless f == m.from
        send_message_to(f, message)
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
