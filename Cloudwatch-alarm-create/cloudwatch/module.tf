module "cloudwatch_alarm_exchange" {
  source = "./alarm"
  db_instance_id = var.exchange_db_instance_id
  alarm_name = var.exchange_alarm
}

module "cloudwatch_alarm_versus" {
  source = "./alarm"
  alarm_name = var.versus_alarm  
  db_instance_id = var.versus_db_instance_id
}
