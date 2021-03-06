class InvoicesController < ApplicationController

  around_filter :shopify_session
  before_filter :load_shop


  def index
    if @shop.invoicexpress_ready?
      begin
        if @shop.invoicexpress_can_connect?
          api_client    = @shop.get_invoicexpress_client
          api_invoices  = api_client.invoices(:page =>params[:page])
          @invoices     = Kaminari.paginate_array(api_invoices.invoices, total_count: api_invoices.total_entries).page(api_invoices.current_page).per(api_invoices.per_page)
          invoice_ids   = @invoices.map(&:id)
          @db_invoices  = @shop.invoices.where(:invoice_id => invoice_ids)
        else
          @invoices=[]
          @msg="Can't connect to InvoiceXpress. Please try again a bit later."
        end
      rescue Timeout::Error
        redirect_to trouble_path
      end
    else
      @invoices=[]
      @msg="Please fill in your InvoiceXpress API Key and Username in the Setup Page to connect to InvoiceXpress."
    end

    #@invoices = @shop.invoices.order("created_at DESC").page params[:page]
  end

  def new
    @payment = nil
    order   = nil

    if @shop && params[:order_id]
      order = ShopifyAPI::Order.find(params[:order_id])
      if order
        #fill general data
        #debugger
        @invoice=Invoice.new(
          :store_url=>      ShopifyAPI::Shop.current.domain,
          :order_id=>       order.id,
          :shop_id=>        @shop.id,
          :order_number=>   order.name,
          :total=>          order.total_price,
          :email=>          order.email,
          :name=>           "#{order.customer.first_name} #{order.customer.last_name}"
          )
      else
        redirect_to root_path, :notice=>'That order does not exist.'
      end
    else
      #logger.debug("send_payment_information: No params sent or shop is nil #{@shop}")
      redirect_to root_path, :notice=>'No params sent or shop is nil'
    end

  end

  # manually creates
  def create
    if @shop && params[:invoice]
      @invoice = Invoice.new(params[:invoice])
      status   = @invoice.create_invoicexpress()

      if status==true
        if @invoice.save
          if @shop.auto_send_email==true
            redirect_to send_email_invoice_path(@invoice.id)
          else
            redirect_to invoices_path, :notice=>'Invoice was created with success.'
          end
        else
          render :new, :notice=>'There were problems with the form, please fill the missing information.'
        end
      else
        redirect_to invoices_path(:page=>params[:page]), :alert=>"There was problem creating the invoice: #{status}."
      end

    else
      render :new, :alert=>'No params sent or shop is nil'
    end
  end

  def send_email
    invoice   = Invoice.find(params[:id])

    if @shop && invoice
      #heads up, this will finalize invoice
      status=invoice.send_email
      if status==true
        redirect_to invoices_path, :notice=>'Sent Invoice to '+invoice.email
      else

        redirect_to invoices_path(:page=>params[:page]), :alert=>"There was problem sending the email: #{status}."
      end
    else
      redirect_to invoices_path, :alert=>'No params sent or shop is nil'
    end
  end

  private
    def load_shop
      begin
        @shop  = Shop.where(:store_url=>ShopifyAPI::Shop.current.myshopify_domain).first
        if @shop.nil?
          @shop  = Shop.where(:store_url=>ShopifyAPI::Shop.current.domain).first
        end

      rescue Timeout::Error
        redirect_to trouble_path
      end
    end

end
