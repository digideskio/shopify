class HomeController < ApplicationController
  
  around_filter :shopify_session, :except => 'welcome'

  def welcome
    current_host = "#{request.host}#{':' + request.port.to_s if request.port != 80}"
    @callback_url = "http://#{current_host}/login"
  end
  
  def index
    init_shop
    # get latest 5 orders
    @orders   = ShopifyAPI::Order.find(:all, :params => {:limit => 5, :order => "created_at DESC" })
  end

  def setup
    @shop=Shop.where(:store_url => ShopifyAPI::Shop.current.domain).first
  end

  private
  def init_shop
    #debugger
    if Shop.where(:name => ShopifyAPI::Shop.current.name).exists?
      @shop=Shop.where(:store_url => ShopifyAPI::Shop.current.domain).first
      if session["shopify"] && session["shopify"].token != @shop.token
        @shop.name=session[:shop]
        @shop.token=session["shopify"].token
        @shop.save
      end
    else
      @shop = Shop.new(:name => ShopifyAPI::Shop.current.name, :store_url => ShopifyAPI::Shop.current.domain)
      @shop.token=session["shopify"].token if session["shopify"] && session["shopify"].token != @shop.token
      @shop.email=ShopifyAPI::Shop.current.email
      @shop.store_id=ShopifyAPI::Shop.current.id
      @shop.save
      init_webhooks
      session[:shop] = @shop.name
      redirect_to setup_path()
    end
  end
  
  def init_webhooks
    #change this in production!
    #address=""
    if Rails.env.development?
      address="https://thinkorange.pagekite.me/webhooks"
    else
      address="http://shopinvoicexpress.herokuapp.com/webhooks"
    end  
    
    webhook = ShopifyAPI::Webhook.create(:format => "json",  :topic => "orders/paid", :address => address)
    if webhook.valid?
      #debugger
      logger.debug("oh Webhook invalid: #{webhook.errors}")
    else
      logger.debug('Created webhook')
    end
  end
end