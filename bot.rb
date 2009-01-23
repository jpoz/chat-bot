require 'bot_base'

#Jabber::debug = true

config   = YAML.load_file('config.yml')
username = config['bot']['id']
password = config['bot']['password']

BotBase.new(username, password, 'I am a  bot!')
