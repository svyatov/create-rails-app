# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CreateRailsApp::UI::Palette do
  it 'outputs 256-color ANSI codes when TERM supports it' do
    palette = described_class.new(env: { 'TERM' => 'xterm-256color', 'COLORTERM' => '' })
    result = palette.color(:summary_label, 'hello')

    expect(result).to include("\e[38;5;")
    expect(result).to include('hello')
    expect(result).to end_with(described_class::RESET)
  end

  it 'falls back to cli-ui markup on basic terminals' do
    palette = described_class.new(env: { 'TERM' => 'xterm', 'COLORTERM' => '' })
    result = palette.color(:summary_label, 'hello')

    expect(result).to eq('{{magenta:hello}}')
  end

  it 'detects truecolor via COLORTERM' do
    palette = described_class.new(env: { 'TERM' => 'xterm', 'COLORTERM' => 'truecolor' })
    result = palette.color(:arg_name, 'flag')

    expect(result).to include("\e[38;5;")
  end

  it 'supports Rails-specific color roles' do
    palette = described_class.new(env: { 'TERM' => 'xterm-256color', 'COLORTERM' => '' })

    expect(palette.color(:command_app, 'myapp')).to include('myapp')
    expect(palette.color(:install_cmd, 'gem install rails')).to include('gem install rails')
    expect(palette.color(:arg_value, '8.1.0')).to include('8.1.0')
  end

  it 'returns plain text when NO_COLOR is set' do
    palette = described_class.new(env: { 'TERM' => 'xterm-256color', 'COLORTERM' => '', 'NO_COLOR' => '1' })
    result = palette.color(:summary_label, 'hello')

    expect(result).to eq('hello')
    expect(result).not_to include("\e[")
  end

  it 'returns plain text with NO_COLOR on basic terminal' do
    palette = described_class.new(env: { 'TERM' => 'xterm', 'COLORTERM' => '', 'NO_COLOR' => '' })
    result = palette.color(:arg_name, 'flag')

    expect(result).to eq('flag')
    expect(result).not_to include('{{')
  end

  it 'returns plain text when TERM=dumb' do
    palette = described_class.new(env: { 'TERM' => 'dumb', 'COLORTERM' => '' })
    result = palette.color(:summary_label, 'hello')

    expect(result).to eq('hello')
    expect(result).not_to include("\e[")
  end

  it 'raises KeyError for unknown role on 256-color terminal' do
    palette = described_class.new(env: { 'TERM' => 'xterm-256color', 'COLORTERM' => '' })

    expect { palette.color(:unknown_role, 'text') }.to raise_error(KeyError)
  end

  it 'raises KeyError for unknown role on basic terminal' do
    palette = described_class.new(env: { 'TERM' => 'xterm', 'COLORTERM' => '' })

    expect { palette.color(:unknown_role, 'text') }.to raise_error(KeyError)
  end
end
