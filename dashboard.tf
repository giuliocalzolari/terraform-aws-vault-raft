# https=//github.com/strvcom/terraform-aws-fargate/blob/master/metrics/basic-dashboard.json
locals {
  dashboard_infra = {
    start          = "-PT4H"
    end            = null
    periodOverride = null
    widgets = [
      {
        "type"   = "metric",
        "x"      = 0,
        "y"      = 12,
        "width"  = 12,
        "height" = 6,
        "properties" = {
          "metrics" = [
            ["AWS/EC2", "EBSReadOps", "AutoScalingGroupName", aws_autoscaling_group.asg.name],
            [".", "EBSWriteOps", ".", "."]
          ],
          "view"    = "timeSeries",
          "stacked" = true,
          "region"  = local.aws_region,
          "title"   = "Disks",
          "period"  = 300
        }
      },
      {
        "type"   = "metric",
        "x"      = 0,
        "y"      = 6,
        "width"  = 12,
        "height" = 6,
        "properties" = {
          "metrics" = [
            ["AWS/EC2", "NetworkOut", "AutoScalingGroupName", aws_autoscaling_group.asg.name],
            [".", "NetworkIn", ".", "."]
          ],
          "view"    = "timeSeries",
          "stacked" = true,
          "region"  = local.aws_region,
          "title"   = "Network",
          "period"  = 300
        }
      },
      {
        "type"   = "metric",
        "x"      = 21,
        "y"      = 3,
        "width"  = 3,
        "height" = 9,
        "properties" = {
          "metrics" = [
            ["AWS/ApplicationELB", "TargetResponseTime", "TargetGroup", aws_alb_target_group.main.arn_suffix, "LoadBalancer", aws_alb.main.arn_suffix, "AvailabilityZone", "${local.aws_region}a"],
            ["...", aws_alb_target_group.main.arn_suffix, ".", aws_alb.main.arn_suffix, ".", "${local.aws_region}b"],
            ["...", aws_alb_target_group.main.arn_suffix, ".", aws_alb.main.arn_suffix, ".", "${local.aws_region}c"],
          ],
          "view"   = "singleValue",
          "region" = local.aws_region,
          "title"  = "Latency",
          "period" = 300
        }
      },
      {
        "type"   = "metric",
        "x"      = 21,
        "y"      = 0,
        "width"  = 3,
        "height" = 3,
        "properties" = {
          "view" = "singleValue",
          "metrics" = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_alb.main.arn_suffix]
          ],
          "region" = local.aws_region,
          "title"  = "Requests"
        }
      },
      {
        "type"   = "metric",
        "x"      = 0,
        "y"      = 0,
        "width"  = 12,
        "height" = 6,
        "properties" = {
          "view"    = "timeSeries",
          "stacked" = true,
          "metrics" = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.asg.name]
          ],
          "region" = local.aws_region,
          "title"  = "CPU Utilization"
        }
      },
      {
        "type"   = "metric",
        "x"      = 12,
        "y"      = 6,
        "width"  = 9,
        "height" = 6,
        "properties" = {
          title     = "HTTPCode_Target_3XX_4XX_Count"
          "view"    = "timeSeries",
          "stacked" = false,
          "metrics" = [
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "TargetGroup", aws_alb_target_group.main.arn_suffix, "LoadBalancer", aws_alb.main.arn_suffix],
            [".", "HTTPCode_Target_3XX_Count", ".", ".", ".", "."]
          ],
          "region" = local.aws_region
        }
      },
      {
        "type"   = "metric",
        "x"      = 12,
        "y"      = 12,
        "width"  = 12,
        "height" = 6,
        "properties" = {
          title     = "HTTPCode_ELB_5XX_Count"
          "view"    = "timeSeries",
          "stacked" = false,
          "metrics" = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_alb.main.arn_suffix],
            [".", "HTTPCode_ELB_503_Count", ".", "."]
          ],
          "region" = local.aws_region
        }
      },
      {
        "type"   = "metric",
        "x"      = 12,
        "y"      = 0,
        "width"  = 9,
        "height" = 6,
        "properties" = {
          title     = "UnHealthy - Healthy Host Count"
          "view"    = "timeSeries",
          "stacked" = true,
          "metrics" = [
            ["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", aws_alb_target_group.main.arn_suffix, "LoadBalancer", aws_alb.main.arn_suffix],
            [".", "HealthyHostCount", ".", ".", ".", "."]
          ],
          "region" = local.aws_region
        }
      }
    ]
  }

  dashboard_app = {
    start          = "-PT4H"
    end            = null
    periodOverride = null
    widgets = [
      {
        height = 5
        properties = {
          metrics = [
            [
              format("%s-n", local.base_name),
              format("vault_core_unsealed_%s", local.base_name),
              "metric_type",
              "gauge",
            ],
          ]
          region  = local.aws_region
          stacked = false
          title   = "Sealed Status"
          view    = "timeSeries"
          yAxis = {
            left = {
              showUnits = true
            }
          }
        }
        type  = "metric"
        width = 12
        x     = 0
        y     = 0
      },
      {
        height = 5
        properties = {
          metrics = [
            [
              {
                expression = format("SEARCH('{%s-n} vault_autopilot_node_healthy', 'Average', 300)", local.base_name)
                id         = "e1"
                period     = 300
              },
            ],
          ]
          region  = local.aws_region
          stacked = false
          title   = "Healthy Status"
          view    = "timeSeries"
          yAxis = {
            left = {
              showUnits = true
            }
          }
        }
        type  = "metric"
        width = 12
        x     = 12
        y     = 0
      },
      {
          height     = 6
          properties = {
              metrics = [
                  [
                      {
                          expression = format("SEARCH('{%s-n} vault_token_count_by_auth', 'Average', 300)", local.base_name)
                          id         = "e1"
                          period     = 300
                        },
                    ],
                ]
              region  = local.aws_region
              title   = "Tokens by Auth Method"
              view    = "pie"
            }
          type       = "metric"
          width      = 6
          x          = 0
          y          = 5
        },
      {
          height     = 6
          properties = {
              metrics = [
                  [
                      {
                          expression = format("SEARCH('{%s-n} vault_identity_entity_alias_count', 'Average', 300)", local.base_name)
                          id         = "e1"
                          period     = 300
                        },
                    ],
                ]
              region  = local.aws_region
              title   = "Identity Entities Aliases by Method"
              view    = "pie"
            }
          type       = "metric"
          width      = 6
          x          = 6
          y          = 5
        },
      {
          height     = 6
          properties = {
              metrics = [
                  [
                      format("%s-n", local.base_name),
                      "vault_token_lookup",
                    ],
                ]
              region  = local.aws_region
              stacked = false
              title   = "Token Lookups"
              view    = "timeSeries"
            }
          type       = "metric"
          width      = 12
          x          = 12
          y          = 5
        },
      {
          height     = 4
          properties = {
              metrics = [
                  [
                      format("%s-n", local.base_name),
                      "vault_raft_get",
                    ],
                    [
                      ".",
                      "vault_raft_list",
                    ],
                    [
                      ".",
                      "vault_raft_delete",
                    ],
                    [
                      ".",
                      "vault_raft_put",
                    ],
                ]
              region  = local.aws_region
              stacked = false
              title   = "Raft Requests"
              view    = "timeSeries"
            }
          type       = "metric"
          width      = 12
          x          = 0
          y          = 11
        },
      {
          height     = 4
          properties = {
              metrics = [
                  [
                      {
                          expression = format("SEARCH('{%s-n} vault_audit_log_request', 'Average', 300)", local.base_name)
                          id         = "e1"
                          period     = 300
                        },
                    ],
                ]
              region  = local.aws_region
              stacked = false
              view    = "timeSeries"
            }
          type       = "metric"
          width      = 12
          x          = 12
          y          = 11
        },
    ]
  }
}


resource "aws_cloudwatch_dashboard" "dashboard-infra" {
  dashboard_body = jsonencode(local.dashboard_infra)
  dashboard_name = format("%s-infra", local.base_name)
}

resource "aws_cloudwatch_dashboard" "dashboard-app" {
  dashboard_body = jsonencode(local.dashboard_app)
  dashboard_name = format("%s-app", local.base_name)
}


