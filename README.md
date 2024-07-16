# WordPress Setup via Terraform on AWS

Setting up WordPress on AWS using Terraform provides a scalable and reliable infrastructure for your WordPress site. Terraform, as an Infrastructure as Code (IaC) tool, ensures that your infrastructure is version-controlled, reproducible, and easily maintainable. By leveraging AWS's cloud services, you can achieve high availability, security, and performance for your WordPress application.

## Table of Contents

- [Terraform Configurataion](#terraform-configuration)
- [Prerequisits](#prerequisits)
- [Usage](#usage)
- [Additional Notes](#additional-notes)
- [Clean Up](#clean-up)
- [Contributing](#contributing)

## Terraform Configuration

This Terraform configuration file creates and sets up the following AWS resources to host a WordPress site:

### VPC and Subnets

A Virtual Private Cloud (VPC) and three subnets in different availability zones to ensure high availability.
An Internet Gateway for outbound internet access.
Route tables and associations to route traffic appropriately.

### Security Groups

Security groups to allow HTTP, HTTPS, and SSH access.
A security group specifically for the RDS (MySQL) instance to allow MySQL traffic.

### RDS Instance

An Amazon RDS MySQL instance to host the WordPress database.

### WordPress Setup Instance

An EC2 instance to set up WordPress and create an Amazon Machine Image (AMI) from it.

### Load Balancer and Auto Scaling

An Application Load Balancer to distribute traffic to WordPress instances.
An Auto Scaling Group to ensure that the WordPress instances are scaled according to demand.

## Prerequisits

Before you can use this Terraform configuration to set up WordPress on AWS, you need the following:

1. AWS Account: Ensure you have an AWS account with appropriate permissions to create the resources mentioned above.
2. Terraform Installed: Install Terraform on your local machine. You can download it from here.
3. AWS CLI Configured: Configure the AWS CLI with your credentials. You can follow the instructions here.

## Usage

Follow these steps to set up WordPress on your own AWS account using this Terraform configuration:

### Clone the Repository

```bash
git clone <your-repo-url>
cd <your-repo-directory>
```

### Initialize Terraform

Initialize Terraform to install the necessary providers and modules.

```bash
terraform init
```

### Plan the Infrastructure

Run the terraform plan command to see what resources will be created.

```bash
terraform plan
```

### Apply the Configuration

Apply the Terraform configuration to create the resources.

```bash
terraform apply
```

### Access Your WordPress Site

Once the infrastructure is created, you can access your WordPress site using the DNS name of the load balancer that is provided via a Terraform output.

## Additional Notes

1. Security: Ensure you handle sensitive information, such as database passwords, securely. Consider using AWS Secrets Manager for managing secrets.
2. Scaling: The Auto Scaling Group is set to maintain a single instance for simplicity. Adjust the desired capacity, minimum, and maximum size based on your needs.
3. AMI Creation: The configuration includes steps to create an AMI from a setup instance. This AMI is used for launching WordPress instances in the Auto Scaling Group.

## Clean Up

To avoid incurring unnecessary costs, destroy the Terraform-managed infrastructure when you no longer need it.

```bash
terraform destroy
```

## Contributing

If you have ideas for improvements or have already implemented them, please open a [GitHub Issue](../../issues) or a [Pull Request](../../pulls).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
