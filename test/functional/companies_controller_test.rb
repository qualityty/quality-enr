require 'test_helper'

class CompaniesControllerTest < ActionController::TestCase
  def test_index
    get :index
    assert_template 'index'
  end

  def test_show
    get :show, :id => Companies.first
    assert_template 'show'
  end

  def test_new
    get :new
    assert_template 'new'
  end

  def test_create_invalid
    Companies.any_instance.stubs(:valid?).returns(false)
    post :create
    assert_template 'new'
  end

  def test_create_valid
    Companies.any_instance.stubs(:valid?).returns(true)
    post :create
    assert_redirected_to companies_url(assigns(:companies))
  end

  def test_edit
    get :edit, :id => Companies.first
    assert_template 'edit'
  end

  def test_update_invalid
    Companies.any_instance.stubs(:valid?).returns(false)
    put :update, :id => Companies.first
    assert_template 'edit'
  end

  def test_update_valid
    Companies.any_instance.stubs(:valid?).returns(true)
    put :update, :id => Companies.first
    assert_redirected_to companies_url(assigns(:companies))
  end

  def test_destroy
    companies = Companies.first
    delete :destroy, :id => companies
    assert_redirected_to companies_url
    assert !Companies.exists?(companies.id)
  end
end
