# frozen_string_literal: true

class FakePrompter
  attr_reader :seen_options, :seen_questions, :messages

  def initialize(choices: [], texts: [], confirms: [])
    @choices = choices
    @texts = texts
    @confirms = confirms
    @seen_options = []
    @seen_questions = []
    @messages = []
  end

  def frame(_title)
    yield if block_given?
  end

  def choose(question, options:, default: nil)
    @seen_questions << question
    @seen_options << options
    value = @choices.shift
    return value if value == CreateRailsApp::Wizard::BACK

    value ||= default || options.first
    unless options.include?(value)
      labeled = options.find do |option|
        strip_markup(option).gsub(/\n+/, '').sub(/ \(default\)\z/, '').sub(/ - .+\z/, '') == value
      end
      value = labeled unless labeled.nil?
    end

    value
  end

  def text(_question, default: nil, allow_empty: true)
    value = @texts.shift
    value = default if value.nil?
    value = '' if value.nil? && allow_empty
    value
  end

  def confirm(_question, default: true)
    value = @confirms.shift
    value.nil? ? default : value
  end

  def say(message)
    @messages << message
  end

  private

  def strip_markup(value)
    value.gsub(/\{\{[^:}]+:/, '').gsub('}}', '')
  end
end
