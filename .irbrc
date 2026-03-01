def eba(emp)
  SfgSecurityClient.set_sfg_client_api_from_employee(emp)
  SfgPolicyClient.set_sfg_client_api(emp)
end

if defined?(Rails) && Rails.application.class.module_parent_name == 'Eba'
  SfgSecurityClient.set_sfg_client_state(User.api_user, User.api_user.groups.join(','))
  eba(Employee.last) if Employee.last.present?
end

IRB.conf[:SAVE_HISTORY] = 10000
Reline::Face.config(:completion_dialog) do |conf|
  conf.define :default, foreground: :white, background: :black
  conf.define :enhanced, foreground: :black, background: :white
  conf.define :scrollbar, foreground: :white, background: :black
end


