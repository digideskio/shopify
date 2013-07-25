class Shop < ActiveRecord::Base
  attr_accessible :email, :invoice_api, :invoice_user, :name, :store_url, :finalize_invoice, :auto_send_email, :auto_sequence, :sequence_id, :vat_code_default, :vat_code_inside_eu, :vat_code_outside_eu, :store_id, :token
  
  has_many :invoices
  #validates_presence_of :invoice_user, :invoice_api
  def invoicexpress_ready?
    if invoice_api.nil? || invoice_user.nil? || invoice_api.empty? || invoice_user.empty?
      false
    else
      true
    end
  end

  def invoicexpress_can_connect?
    begin
      client= Invoicexpress::Client.new(
        :screen_name => invoice_user,
        :api_key     => invoice_api
      )
      if client.clients
        true
      else
        false
      end
    rescue Exception=>e
      false
    end
  end

end
