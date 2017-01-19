require 'spec_helper'

describe DockerRailsApp do
  it 'has a version number' do
    expect(DockerRailsApp::VERSION).not_to be nil
  end

  it 'does something useful' do
    expect(false).to eq(true)
  end
end
