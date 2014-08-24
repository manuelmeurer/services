guard 'rspec', cmd: 'bundle exec rspec' do
  # Specs
  watch(%r(^spec/.+_spec\.rb$))
  watch('spec/spec_helper.rb')       { 'spec' }
  watch(%r(^spec/support/(.+)\.rb$)) { 'spec' }

  # Files
  watch(%r(^lib/(.+)\.rb$))          { |m| "spec/#{m[1]}_spec.rb" }
end
