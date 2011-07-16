module CompaniesHelper
  def selected_options sel = "2"
    options = %w[ 2 5 10 25 50 100 500 1000]
    if options.include? sel
      option.delete sel
    end
  end
end
