# frozen_string_literal: true

Redmine::Plugin.register :redmine_test_plugin do
  name 'Redmine Test Plugin'
  author 'Adria Cloud Services'
  description 'Test plugin v2 for ansible-role-redmine Molecule verification'
  version '0.0.2'
  requires_redmine version_or_higher: '6.0.0'
end
