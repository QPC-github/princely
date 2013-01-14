module PdfHelper
  require 'princely'
  
  def self.included(base)
    base.class_eval do
      alias_method_chain :render, :princely
    end
  end
  
  def render_with_princely(options = nil, *args, &block)
    if options.is_a?(Hash) && options.has_key?(:pdf)
      options[:name] ||= options.delete(:pdf)
      make_and_send_pdf(options.delete(:name), options)      
    else
      render_without_princely(options, *args, &block)
    end
  end  
    
  private
  
  def make_pdf(options = {})
    options[:stylesheets] ||= []
    options[:layout] ||= false
    options[:template] ||= File.join(controller_path,action_name)
    
    prince = Princely.new()
    # Sets style sheets on PDF renderer
    prince.add_style_sheets(*options[:stylesheets].collect{|style| asset_file_path(style)})
    
    html_string = render_to_string(:template => options[:template], :layout => options[:layout])
    
    # Make all paths relative, on disk paths...
    html_string.gsub!(".com:/",".com/") # strip out bad attachment_fu URLs
    html_string.gsub!( /src=["']+([^:]+?)["']/i ) { |m|  puts $1; "src=\"#{asset_file_path($1) || $1}\"" } # re-route absolute paths
    
    # Remove asset ids on images with a regex
    html_string.gsub!( /src=["'](\S+\?\d*)["']/i ) { |m| 'src="' + $1.split('?').first + '"' }
    
    # Send the generated PDF file from our html string.
    if filename = options[:filename] || options[:file]
      prince.pdf_from_string_to_file(html_string, filename)
    else
      prince.pdf_from_string(html_string)
    end
  end

  def make_and_send_pdf(pdf_name, options = {})
    options[:disposition] ||= 'attachment'
    send_data(
      make_pdf(options),
      :filename => pdf_name + ".pdf",
      :type => 'application/pdf',
      :disposition => options[:disposition]
    ) 
  end
  
  def asset_file_path(asset)
    # remove /asset/ in generated paths
    asset.gsub!(/\/assets\//, "")
    
    if Rails.configuration.assets.compile == false
      if ActionController::Base.asset_host
        # asset_path returns an absolute URL using asset_host if asset_host is set
        asset_path(asset)
      else
        File.join(Rails.public_path, asset_path(asset))
      end
    else
      Rails.application.assets.find_asset(asset).try(:pathname)
    end
  end
  alias_method :stylesheet_file_path, :asset_file_path
end
