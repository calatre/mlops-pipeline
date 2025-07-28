# ALB Listener Rule for Airflow
resource "aws_lb_listener_rule" "airflow" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 300
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.airflow.arn
  }
  
  condition {
    path_pattern {
      values = ["/airflow*"]
    }
  }
}
