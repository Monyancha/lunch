require 'rails_helper'

RSpec.describe MessagesController, :type => :controller do

  describe 'GET index' do
    let(:message_service_instance) { double('MessageServiceInstance') }
    let(:messages) { double('Array of Messages') }
    it 'should render the index view' do
      get :index
      expect(response.body).to render_template('index')
    end
    it 'should set @sidebar_options as an array of options with a label and a value' do
      get :index
      expect(assigns[:sidebar_options]).to be_kind_of(Array)
      assigns[:sidebar_options].each do |option|
        expect(option.first).to be_kind_of(String)
        expect(option.last).to be_kind_of(String)
      end
    end
    it 'should set @messages to the value returned by MessageService#corporate_communications' do
      expect(message_service_instance).to receive(:corporate_communications).and_return(messages)
      expect(MessageService).to receive(:new).and_return(message_service_instance)
      get :index
      expect(assigns[:messages]).to eq(messages)
    end
  end

end