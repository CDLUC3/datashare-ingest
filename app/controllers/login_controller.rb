class LoginController < ApplicationController
  
  
  def login
    user = User.find_by_external_id(request.headers[DATASHARE_CONFIG['external_identifier']])
    
    if user.nil?
      user = User.new
      user.external_id = request.headers[DATASHARE_CONFIG['external_identifier']]
      user.email = request.headers[DATASHARE_CONFIG['email']]
      user.save
    else
      if user.email.blank?
        user.email = request.headers[DATASHARE_CONFIG['email']]
        user.save
      end
    end
    
    session[:user_id] = user.id

    redirect_to "/records"
  end
  
  def logout
    reset_session
    redirect_to DATASHARE_CONFIG['logout_path']
  end
  
  # login and logout pages aren't used in prod
  # shib will protect the directory
  # these methods are available for runnign theapp
  # in dev without shib or another authentication system
  def login_page
  end
  
  def logout_page
    render :layout => false
  end
  
end
