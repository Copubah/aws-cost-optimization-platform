# Contributing Guide

Thank you for your interest in contributing to the AWS Cost Optimization & Reliability Platform!

## How to Contribute

### Reporting Issues

1. Check existing issues to avoid duplicates
2. Use the issue template
3. Include:
 - Clear description
 - Steps to reproduce
 - Expected vs actual behavior
 - Environment details
 - Relevant logs

### Suggesting Enhancements

1. Open an issue with the "enhancement" label
2. Describe the feature and use case
3. Explain why it would be valuable
4. Consider implementation approach

### Code Contributions

#### Prerequisites

- AWS Account for testing
- Terraform >= 1.5.0
- Python 3.11+
- Git
- AWS CLI configured

#### Development Setup

```bash
# Clone the repository
git clone <repository-url>
cd aws-cost-optimization

# Create a feature branch
git checkout -b feature/your-feature-name

# Make your changes
# Test thoroughly
```

#### Coding Standards

Terraform
- Use consistent formatting: `terraform fmt -recursive`
- Validate syntax: `terraform validate`
- Use meaningful variable names
- Add comments for complex logic
- Follow module structure

Python
- Follow PEP 8 style guide
- Use type hints
- Add docstrings for functions
- Handle exceptions properly
- Write unit tests

Documentation
- Update README.md if needed
- Add inline comments
- Update relevant docs/ files
- Include examples

#### Testing Requirements

Before submitting:

1. Terraform Validation
```bash
cd terraform
terraform init
terraform validate
terraform fmt -check -recursive
```

2. Python Linting
```bash
pylint lambda//.py
```

3. Security Scan
```bash
tfsec terraform/
```

4. Functional Testing
```bash
# Deploy to dev environment
terraform apply -var-file=environments/dev/terraform.tfvars

# Run validation script
./scripts/validate-deployment.sh dev

# Test Lambda functions
aws lambda invoke --function-name <function> --payload '{}' response.json
```

#### Pull Request Process

1. Create PR
 - Use descriptive title
 - Reference related issues
 - Describe changes clearly
 - Include testing evidence

2. PR Checklist
 - [ ] Code follows style guidelines
 - [ ] Tests pass
 - [ ] Documentation updated
 - [ ] No security vulnerabilities
 - [ ] Terraform plan reviewed
 - [ ] Backward compatible (or breaking changes documented)

3. Review Process
 - Address reviewer feedback
 - Keep PR focused and small
 - Squash commits if requested

4. Merge
 - Maintainer will merge after approval
 - Delete feature branch after merge

## Project Structure

```
.
 docs/ # Documentation
 lambda/ # Lambda function code
 cost_optimizer/ # Cost optimization functions
 notifications/ # Notification handlers
 terraform/ # Infrastructure as Code
 modules/ # Reusable Terraform modules
 environments/ # Environment-specific configs
 scripts/ # Helper scripts
```

## Module Development

### Creating a New Terraform Module

```bash
# Create module directory
mkdir -p terraform/modules/my-module

# Create required files
touch terraform/modules/my-module/{main.tf,variables.tf,outputs.tf}
```

Module Structure:
```hcl
# main.tf - Resource definitions
resource "aws_example" "main" {
 # Resource configuration
}

# variables.tf - Input variables
variable "example_var" {
 description = "Description"
 type = string
}

# outputs.tf - Output values
output "example_output" {
 description = "Description"
 value = aws_example.main.id
}
```

### Creating a New Lambda Function

```bash
# Create function directory
mkdir -p lambda/my-function

# Create files
touch lambda/my-function/{__init__.py,handler.py,requirements.txt}
```

Lambda Structure:
```python
# handler.py
import json
import boto3

def lambda_handler(event, context):
 """
 Lambda function handler
 
 Args:
 event: Lambda event object
 context: Lambda context object
 
 Returns:
 Response dictionary
 """
 try:
 # Your logic here
 return {
 'statusCode': 200,
 'body': json.dumps({'message': 'Success'})
 }
 except Exception as e:
 return {
 'statusCode': 500,
 'body': json.dumps({'error': str(e)})
 }
```

## Documentation

### Adding Documentation

1. Architecture Changes
 - Update docs/ARCHITECTURE.md
 - Update diagrams if needed

2. New Features
 - Add to README.md
 - Create detailed guide in docs/
 - Update QUICKSTART.md if relevant

3. API Changes
 - Document in code comments
 - Update relevant guides

### Documentation Style

- Use clear, concise language
- Include code examples
- Add diagrams where helpful
- Keep formatting consistent
- Test all commands

## Testing Guidelines

### Unit Tests

```python
# tests/test_cost_optimizer.py
import unittest
from lambda.cost_optimizer import stop_dev_instances

class TestCostOptimizer(unittest.TestCase):
 def test_stop_instances(self):
 result = stop_dev_instances.stop_dev_ec2_instances(dry_run=True)
 self.assertIsNotNone(result)
```

### Integration Tests

```bash
# Test budget alert flow
aws lambda invoke \
 --function-name budget-handler \
 --payload '{"test": true}' \
 response.json

# Verify response
cat response.json
```

### Manual Testing

1. Deploy to dev environment
2. Verify all resources created
3. Test cost automation (dry run)
4. Test monitoring alerts
5. Verify cleanup works

## Security

### Security Best Practices

1. Never commit secrets
 - Use AWS Secrets Manager
 - Use environment variables
 - Add to .gitignore

2. Follow least privilege
 - Minimal IAM permissions
 - Scope resources appropriately
 - Use conditions in policies

3. Validate inputs
 - Sanitize user inputs
 - Validate event data
 - Handle errors gracefully

4. Scan for vulnerabilities
```bash
# Terraform security scan
tfsec terraform/

# Python dependency check
safety check -r lambda/requirements.txt
```

## Release Process

### Version Numbering

Follow Semantic Versioning (SemVer):
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes

### Creating a Release

1. Update version in relevant files
2. Update CHANGELOG.md
3. Create git tag
4. Push tag to trigger release

```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

## Community

### Communication

- GitHub Issues: Bug reports and feature requests
- GitHub Discussions: Questions and ideas
- Pull Requests: Code contributions

### Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Focus on constructive feedback
- Assume good intentions

## Getting Help

### Resources

- [Documentation](docs/)
- [Architecture Guide](docs/ARCHITECTURE.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Testing Guide](docs/TESTING.md)

### Questions

- Check existing issues
- Review documentation
- Ask in GitHub Discussions
- Provide context and details

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Mentioned in release notes
- Credited in documentation

Thank you for contributing! 
