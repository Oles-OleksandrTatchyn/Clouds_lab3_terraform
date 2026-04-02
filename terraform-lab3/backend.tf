terraform {
  backend "s3" {
    bucket       = "tf-state-lab3-tatchyn-oles-19"
    key          = "env/dev/var-19.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
