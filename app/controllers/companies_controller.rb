class CompaniesController < ApplicationController
  def index
    if params[:per_page]
      @per_page = params[:per_page]
    else
      @per_page = 25
    end
    @companies = Companies.paginate :page => params[:page], :per_page => @per_page

    respond_to do |format|
      format.html
      format.csv do
        require 'csv'
        csv_string = CSV.generate do |csv|
          # header row
          csv << ["id", "name", "serial number", "address", "telephone"]

          # data rows
          Companies.all.each do |company|
            csv << [company.id, company.name, company.serial_num, company.address, company.telephone]
          end
        end

        # send it to the browsah
        send_data csv_string,
                  :type => 'text/csv; charset=iso-8859-15; header=present',
                  :disposition => "attachment; filename=companies.csv"
      end
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
