class CompaniesController < ApplicationController

  def index
    @per_page = ( params[:per_page] ? params[:per_page] : @per_page = 25 )
    @page = params[:page] if params[:page]
    if params[:done]
      session[:done] = (params[:done] == "done" ? "done" : "todo")
    else
      session[:done] = nil
    end
    @companies = Companies.filter_companies(session[:done]).paginate :page => params[:page], :per_page => @per_page
    respond_to do |format|
      format.html
      format.csv do
        require 'csv'
        csv_string = CSV.generate do |csv|
          # header row
          csv << ["Id", "Name", "Serial number", "Zip code", "City", "Website", "Address", "Telephone"]

          # data rows
          Companies.all.each do |company|
            csv << [company.id, company.name, company.serial_num, company.zip_code, 
              company.city, company.web, company.address, company.telephone]
          end
        end
        # send it to the browsah
        send_data csv_string,
                  :type => 'text/csv; charset=iso-8859-15; header=present',
                  :disposition => "attachment; filename=companies.csv"
      end
    end
  end

  def done
    @company = Companies.find(params[:id])
    @company.validated = ( @company.validated ? false : true )
    if @company.save
      redirect_to request.referer, :notice => "#{@company.name}' status successfully updated !"
    else
      redirect_to companies_url, :error => "Something went wrong, unable to change #{@company.name}' status :()"
    end
  end

  def show
    @companies = Companies.find(params[:id])
  end

  def new
    @companies = Companies.new
  end

  def create
    @companies = Companies.new(params[:companies])
    if @companies.save
      redirect_to @companies, :notice => "Successfully created companies."
    else
      render :action => 'new'
    end
  end

  def edit
    @companies = Companies.find(params[:id])
    session[:prev_page] = request.referer 
  end

  def update
    @companies = Companies.find(params[:id])
    if @companies.update_attributes(params[:companies])
      redirect_to session[:prev_page], :notice => "Successfully updated #{@companies.name}."
    else
      render :action => 'edit'
    end
  end

  def destroy
    @companies = Companies.find(params[:id])
    @companies.destroy
    redirect_to companies_url, :notice => "Successfully destroyed companies."
  end
end
