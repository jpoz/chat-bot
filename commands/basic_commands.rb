Command /^(hello|hi|sup|greetings)$/i do
  "Hello"
end

Command /^(thank)(.*)$/i do
  "No thank you!"
end

Command /^how are you(.*)$/i do
  "I'm good!"
end

Command(/^I'm (.*)$/i) do |something|
  something[0].gsub!(/you/, "me")
  "I'm so glad you are #{something}"
end

Command /^do you (wanna|want to) (.*)$/i do
  "Yes I do"
end