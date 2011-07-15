class CompaniesController < ApplicationController
  def index
    @companies = Companies.paginate :page => params[:page], :per_page => 100
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
  end

  def update
    @companies = Companies.find(params[:id])
    if @companies.update_attributes(params[:companies])
      redirect_to @companies, :notice  => "Successfully updated companies."
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
