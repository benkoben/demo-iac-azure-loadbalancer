env="dev"
location="westeurope"
resource_group_name="General_Ben"
web_tier_source_image_id="/subscriptions/<subid>/resourceGroups/General_Ben/providers/Microsoft.Compute/images/demo-web-weeu-dev-001"
business_tier_001_source_image_id="/subscriptions/<subid>/resourceGroups/General_Ben/providers/Microsoft.Compute/images/demo-bt-weeu-dev-001"
business_tier_002_source_image_id="/subscriptions/<subid>/resourceGroups/General_Ben/providers/Microsoft.Compute/images/demo-bt-weeu-dev-002"
backend_tier_source_image_id=""
tags = {
    ProjectName  = "demo-project"
    Env          = "dev"
    Owner        = "user@example.com"
    BusinessUnit = "CORP"
    ServiceClass = "Gold"
  }
