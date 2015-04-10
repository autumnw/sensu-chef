cron "check-sensu-api-service" do
  command %w{
  /sbin/service sensu-api status || /sbin/service sensu-api restart > /tmp/check-sensu-api-service.log
  }.join(' ')
end