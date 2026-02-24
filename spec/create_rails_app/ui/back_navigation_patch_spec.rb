# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CreateRailsApp::UI::BackNavigationPatch do
  it 'raises BackKeyPressed on Ctrl+B' do
    base_class = Class.new { def read_char = "\u0002" }
    patched_class = Class.new(base_class) { prepend CreateRailsApp::UI::BackNavigationPatch::PromptReadCharPatch }

    expect { patched_class.new.read_char }.to raise_error(CreateRailsApp::UI::BackKeyPressed)
  end

  it 'raises if CLI::UI::Prompt does not respond to read_char' do
    stub_const('CLI::UI::Prompt', Class.new)
    expect { described_class.apply! }.to raise_error(CreateRailsApp::Error, /read_char/)
  end

  it 'passes through normal characters' do
    base_class = Class.new { def read_char = 'a' }
    patched_class = Class.new(base_class) { prepend CreateRailsApp::UI::BackNavigationPatch::PromptReadCharPatch }

    expect(patched_class.new.read_char).to eq('a')
  end
end
