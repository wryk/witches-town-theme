# frozen_string_literal: true

require 'rails_helper'

describe ApplicationController, type: :controller do
  controller do
    def success
      head 200
    end

    def routing_error
      raise ActionController::RoutingError, ''
    end

    def record_not_found
      raise ActiveRecord::RecordNotFound, ''
    end

    def invalid_authenticity_token
      raise ActionController::InvalidAuthenticityToken, ''
    end
  end

  shared_examples 'respond_with_error' do |code|
    it "returns http #{code} for any" do
      subject
      expect(response).to have_http_status(code)
    end

    it "returns http #{code} for http" do
      subject
      expect(response).to have_http_status(code)
    end

    it "renders template for http" do
      is_expected.to render_template("errors/#{code}", layout: 'error')
    end
  end

  it "does not force ssl if LOCAL_HTTPS is not 'true'" do
    routes.draw { get 'success' => 'anonymous#success' }
    ENV['LOCAL_HTTPS'] = ''
    allow(Rails.env).to receive(:production?).and_return(true)
    get 'success'
    expect(response).to have_http_status(:success)
  end

  it "forces ssl if LOCAL_HTTPS is 'true'" do
    routes.draw { get 'success' => 'anonymous#success' }
    ENV['LOCAL_HTTPS'] = 'true'
    allow(Rails.env).to receive(:production?).and_return(true)
    get 'success'
    expect(response).to redirect_to('https://test.host/success')
  end

  describe 'helper_method :current_account' do
    it 'returns nil if not signed in' do
      expect(controller.view_context.current_account).to be_nil
    end

    it 'returns account if signed in' do
      account = Fabricate(:account)
      sign_in(Fabricate(:user, account: account))
      expect(controller.view_context.current_account).to eq account
    end
  end

  describe 'helper_method :single_user_mode?' do
    it 'returns false if it is in single_user_mode but there is no account' do
      allow(Rails.configuration.x).to receive(:single_user_mode).and_return(true)
      expect(controller.view_context.single_user_mode?).to eq false
    end

    it 'returns false if there is an account but it is not in single_user_mode' do
      allow(Rails.configuration.x).to receive(:single_user_mode).and_return(false)
      Fabricate(:account)
      expect(controller.view_context.single_user_mode?).to eq false
    end

    it 'returns true if it is in single_user_mode and there is an account' do
      allow(Rails.configuration.x).to receive(:single_user_mode).and_return(true)
      Fabricate(:account)
      expect(controller.view_context.single_user_mode?).to eq true
    end
  end

  context 'ActionController::RoutingError' do
    subject do
      routes.draw { get 'routing_error' => 'anonymous#routing_error' }
      get 'routing_error'
    end

    include_examples 'respond_with_error', 404
  end

  context 'ActiveRecord::RecordNotFound' do
    subject do
      routes.draw { get 'record_not_found' => 'anonymous#record_not_found' }
      get 'record_not_found'
    end

    include_examples 'respond_with_error', 404
  end

  context 'ActionController::InvalidAuthenticityToken' do
    subject do
      routes.draw { get 'invalid_authenticity_token' => 'anonymous#invalid_authenticity_token' }
      get 'invalid_authenticity_token'
    end

    include_examples 'respond_with_error', 422
  end

  describe 'before_action :store_current_location' do
    it 'stores location for user if it is not devise controller' do
      routes.draw { get 'success' => 'anonymous#success' }
      get 'success'
      expect(controller.stored_location_for(:user)).to eq '/success'
    end

    context do
      controller Devise::SessionsController do
      end

      it 'does not store location for user if it is devise controller' do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        get 'create'
        expect(controller.stored_location_for(:user)).to be_nil
      end
    end
  end

  describe 'before_action :check_suspension' do
    before do
      routes.draw { get 'success' => 'anonymous#success' }
    end

    it 'does nothing if not signed in' do
      get 'success'
      expect(response).to have_http_status(:success)
    end

    it 'does nothing if user who signed in is not suspended' do
      sign_in(Fabricate(:user, account: Fabricate(:account, suspended: false)))
      get 'success'
      expect(response).to have_http_status(:success)
    end

    it 'returns http 403 if user who signed in is suspended' do
      sign_in(Fabricate(:user, account: Fabricate(:account, suspended: true)))
      get 'success'
      expect(response).to have_http_status(403)
    end
  end

  describe 'raise_not_found' do
    it 'raises error' do
      controller.params[:unmatched_route] = 'unmatched'
      expect{ controller.raise_not_found }.to raise_error(ActionController::RoutingError, 'No route matches unmatched')
    end
  end

  describe 'require_admin!' do
    controller do
      before_action :require_admin!

      def sucesss
        head 200
      end
    end

    before do
      routes.draw { get 'sucesss' => 'anonymous#sucesss' }
    end

    it 'redirects to root path if current user is not admin' do
      sign_in(Fabricate(:user, admin: false))
      get 'sucesss'
      expect(response).to redirect_to('/')
    end

    it 'does nothing if current user is admin' do
      sign_in(Fabricate(:user, admin: true))
      get 'sucesss'
      expect(response).to have_http_status(200)
    end
  end

  describe 'forbidden' do
    controller do
      def route_forbidden
        forbidden
      end
    end

    subject do
      routes.draw { get 'route_forbidden' => 'anonymous#route_forbidden' }
      get 'route_forbidden'
    end

    include_examples 'respond_with_error', 403
  end

  describe 'not_found' do
    controller do
      def route_not_found
        not_found
      end
    end

    subject do
      routes.draw { get 'route_not_found' => 'anonymous#route_not_found' }
      get 'route_not_found'
    end

    include_examples 'respond_with_error', 404
  end

  describe 'gone' do
    controller do
      def route_gone
        gone
      end
    end

    subject do
      routes.draw { get 'route_gone' => 'anonymous#route_gone' }
      get 'route_gone'
    end

    include_examples 'respond_with_error', 410
  end

  describe 'unprocessable_entity' do
    controller do
      def route_unprocessable_entity
        unprocessable_entity
      end
    end

    subject do
      routes.draw { get 'route_unprocessable_entity' => 'anonymous#route_unprocessable_entity' }
      get 'route_unprocessable_entity'
    end

    include_examples 'respond_with_error', 422
  end

  describe 'cache_collection' do
    class C < ApplicationController
      public :cache_collection
    end

    shared_examples 'receives :with_includes' do |fabricator, klass|
      it 'uses raw if it is not an ActiveRecord::Relation' do
        record = Fabricate(fabricator)
        expect(C.new.cache_collection([record], klass)).to match_array([record])
      end
    end

    shared_examples 'cacheable' do |fabricator, klass|
      include_examples 'receives :with_includes', fabricator, klass

      it 'calls cache_ids of raw if it is an ActiveRecord::Relation' do
        record = Fabricate(fabricator)
        relation = klass.none
        allow(relation).to receive(:cache_ids).and_return([record])
        expect(C.new.cache_collection(relation, klass)).to match_array([record])
      end
    end

    it 'returns raw unless class responds to :with_includes' do
      raw = Object.new
      expect(C.new.cache_collection(raw, Object)).to eq raw
    end

    context 'Notification' do
      include_examples 'cacheable', :notification, Notification
    end

    context 'Status' do
      include_examples 'cacheable', :status, Status
    end

    context 'StreamEntry' do
      include_examples 'receives :with_includes', :stream_entry, StreamEntry
    end
  end
end
