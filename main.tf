### us-west-2 is the parent REGION for AWS Los Angeles LOCAL ZONE.
### us-west-2-lax-1a is the AZ for LOS ANGELES for low latency connection. 
### LOCAL ZONE need to be activated in the account. 

#Please disregard the access and secret keys.

provider "aws"{
    region= "us-west-2"
    access_key = "AAAAAAAAAAAAAAAAAAAAA"
    secret_key = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
}

################### DIRECT CONNECT #################
### STUDIO, LOS ANGELES,CA
resource "aws_dx_connection" "studio-dx" {
  name      = "studio-dx"
  bandwidth = "10Gbps"
  location  = "CoreSite LA1, Los Angeles, CA"
}

resource "aws_dx_gateway" "studio-dxgw" {
  name            = "studio-dxgw"
  amazon_side_asn = 64535
}

resource "aws_dx_transit_virtual_interface" "studio-dx-tgw" {
  connection_id = aws_dx_connection.studio-dx.id

  dx_gateway_id  = aws_dx_gateway.studio-dxgw.id
  name           = "tf-transit-vif-studio-tgw"
  vlan           = 4094
  address_family = "ipv4"
  bgp_asn        = 65352
}

### VFX, BURBANK,CA

resource "aws_dx_connection" "VFX-dx" {
  name      = "VFX-dx"
  bandwidth = "10Gbps"
  location  = "Equinix LA3, El Segundo, CA "
}

resource "aws_dx_gateway" "VFX-dxgw" {
  name            = "VFX-dxgw"
  amazon_side_asn = 64530
}

resource "aws_dx_transit_virtual_interface" "studio-dx-tgw" {
  connection_id = aws_dx_connection.VFX-dx.id

  dx_gateway_id  = aws_dx_gateway.VFX-dxgw.id
  name           = "tf-transit-vif-VFX-tgw"
  vlan           = 4094
  address_family = "ipv4"
  bgp_asn        = 65351
}

## Transit gateway can be attached to direct connect gateway
## as announced by aws on April 30, 2020. 

resource "aws_dx_gateway_association" "studio-dxgw-tgw" {
  dx_gateway_id         = aws_dx_gateway.studio-dxgw.id
  associated_gateway_id = aws_ec2_transit_gateway.tf-tgw.id

  allowed_prefixes = [
    "10.0.0.0/8" #advertised IP
  ]
}

resource "aws_dx_gateway_association" "vfx-dxgw-tgw" {
  dx_gateway_id         = aws_dx_gateway.vfx-dxgw.id
  associated_gateway_id = aws_ec2_transit_gateway.tf-tgw.id

  allowed_prefixes = [
    "10.0.0.0/8" #advertised IP
  ]
}

################ TRANSIT GATEWAY ################

resource "aws_ec2_transit_gateway" "tf-tgw" {
  description = "tf-tgw"
  amazon_side_asn = "64550"

  tags = {
        Name = "tf-tgw"
  }
}

################# VPC ATTTACHMENTS ##################

resource "aws_ec2_transit_gateway_vpc_attachment" "web-tgw" {
  subnet_ids         = [aws_subnet.web-subnet-1.id,
                        aws_subnet.web-subnet-2.id]
  transit_gateway_id = aws_ec2_transit_gateway.tf-tgw.id
  vpc_id             = aws_vpc.web-vpc.id

  tags = {
        Name = "web-tgw"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "render-tgw" {
  subnet_ids         = [aws_subnet.render-subnet-1.id,
                        aws_subnet.render-subnet-2.id]
  transit_gateway_id = aws_ec2_transit_gateway.tf-tgw.id
  vpc_id             = aws_vpc.render-vpc.id

  tags = {
        Name = "render-tgw"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "mngt-tgw" {
  subnet_ids         = [aws_subnet.mngt-subnet-1.id,
                        aws_subnet.mngt-subnet-2.id]
  transit_gateway_id = aws_ec2_transit_gateway.tf-tgw.id
  vpc_id             = aws_vpc.mngt-vpc.id

  tags = {
        Name = "mngt-tgw"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "wrkstn-tgw" {
  subnet_ids         = [aws_subnet.wrkstn-subnet-1.id,
                        aws_subnet.wrkstn-subnet-2.id]
  transit_gateway_id = aws_ec2_transit_gateway.tf-tgw.id
  vpc_id             = aws_vpc.wrkstn-vpc.id

  tags = {
        Name = "wrkstn-tgw"
  }
}

################# VPC ATTTACHMENTS ACCEPTOR ##################
# If different account VPCs use this 

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "welcome-vpc" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.web-tgw.id

  tags = {
    Name = "Example cross-account attachment"
  }
}

################### VPC ROUTE TABLES ######################

###  WEB
resource "aws_route_table" "r" {
  vpc_id = aws_vpc.web-vpc.id

  route {
    cidr_block = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tf-tgw.id
  }

  tags = {
    Name = "rt-web-tgw"
  }
}

resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.web-vpc.id
  route_table_id = aws_route_table.r.id
}


### RENDER
resource "aws_route_table" "r1" {
  vpc_id = aws_vpc.render-vpc.id

  route {
    cidr_block = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tf-tgw.id
  }

  tags = {
    Name = "rt-render-tgw"
  }
}

resource "aws_main_route_table_association" "a1" {
  vpc_id         = aws_vpc.render-vpc.id
  route_table_id = aws_route_table.r1.id
}


##### MNGT
resource "aws_route_table" "r2" {
  vpc_id = aws_vpc.mngt-vpc.id

  route {
    cidr_block = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tf-tgw.id
  }

  tags = {
    Name = "rt-mngt-tgw"
  }
}

resource "aws_main_route_table_association" "a2" {
  vpc_id         = aws_vpc.mngt-vpc.id
  route_table_id = aws_route_table.r2.id
}


#### WRKSTN
resource "aws_route_table" "r3" {
  vpc_id = aws_vpc.wrkstn-vpc.id

  route {
    cidr_block = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tf-tgw.id
  }

  tags = {
    Name = "rt-wrkstn-tgw"
  }
}
resource "aws_main_route_table_association" "a3" {
  vpc_id         = aws_vpc.wrkstn-vpc.id
  route_table_id = aws_route_table.r3.id
}

############# WEB APP VPC ###############

#VARIABLE 
variable "subnet_prefix" {
    description = "cidr block for the subnet"
}

#VPC
resource "aws_vpc" "web-vpc" {
    cidr_block       = "10.0.0.0/16"
    instance_tenancy = "default"

    tags = {
        Name = "web-vpc"
  }
}

#SUBNETS
resource "aws_subnet" "web-subnet-1"{
    vpc_id              = aws_vpc.web-vpc.id 
    cidr_block          = var.subnet_prefix[0]
    availability_zone   = "us-west-2a"

    tags = {
        Name = "web-subnet-1"
  }
}
resource "aws_subnet" "web-subnet-2"{
    vpc_id              = aws_vpc.web-vpc.id 
    cidr_block          = var.subnet_prefix[1]
    availability_zone   = "us-west-2b"

    tags = {
        Name = "web-subnet-2"
  }
}
resource "aws_subnet" "app-subnet-1"{
    vpc_id              = aws_vpc.web-vpc.id 
    cidr_block          = var.subnet_prefix[2]
    availability_zone   = "us-west-2a"

    tags = {
        Name = "app-subnet-1"
  }
}
resource "aws_subnet" "app-subnet-2"{
    vpc_id              = aws_vpc.web-vpc.id 
    cidr_block          = var.subnet_prefix[3]
    availability_zone   = "us-west-2b"

    tags = {
        Name = "app-subnet-2"
  }
}
resource "aws_subnet" "rds-subnet-1"{
    vpc_id              = aws_vpc.web-vpc.id 
    cidr_block          = var.subnet_prefix[4]
    availability_zone   = "us-west-2a"

    tags = {
        Name = "rds-subnet-1"
  }
}
resource "aws_subnet" "rds-subnet-2"{
    vpc_id              = aws_vpc.web-vpc.id 
    cidr_block          = var.subnet_prefix[5]
    availability_zone   = "us-west-2b"

    tags = {
        Name = "rds-subnet-2"
  }
}


############# RENDER VPC ###############

#VARIABLE 
variable "render_subnet_prefix" {
    description = "cidr block for the subnet"
}


#VPC
resource "aws_vpc" "render-vpc" {
    cidr_block       = "10.1.0.0/16"
    instance_tenancy = "default"

    tags = {
        Name = "render-vpc"
  }
}

#SUBNETS
resource "aws_subnet" "render-subnet-1"{
    vpc_id              = aws_vpc.render-vpc.id 
    cidr_block          = var.render_subnet_prefix[0]
    availability_zone   = "us-west-2a"

    tags = {
        Name = "render-subnet-1"
  }
}
resource "aws_subnet" "render-subnet-2"{
    vpc_id              = aws_vpc.render-vpc.id 
    cidr_block          = var.render_subnet_prefix[1]
    availability_zone   = "us-west-2b"

    tags = {
        Name = "render-subnet-2"
  }
}




############# MANAGEMENT VPC ###############

#VARIABLE 
variable "mngt_subnet_prefix" {
    description = "cidr block for the subnet"
}


#VPC
resource "aws_vpc" "mngt-vpc" {
    cidr_block       = "10.10.0.0/16"
    instance_tenancy = "default"

    tags = {
        Name = "mngt-vpc"
  }
}

#SUBNETS
resource "aws_subnet" "mngt-subnet-1"{
    vpc_id              = aws_vpc.mngt-vpc.id 
    cidr_block          = var.mngt_subnet_prefix[0]
    availability_zone   = "us-west-2a"

    tags = {
        Name = "mngt-subnet-1"
  }
}
resource "aws_subnet" "mngt-subnet-2"{
    vpc_id              = aws_vpc.mngt-vpc.id 
    cidr_block          = var.mngt_subnet_prefix[1]
    availability_zone   = "us-west-2b"

    tags = {
        Name = "mngt-subnet-2"
  }
}




############# WORKSTATION VPC ###############

#VARIABLE 
variable "wrkstn_subnet_prefix" {
    description = "cidr block for the subnet"
}


#VPC
resource "aws_vpc" "wrkstn-vpc" {
    cidr_block       = "10.100.0.0/16"
    instance_tenancy = "default"

    tags = {
        Name = "wrkstn-vpc"
  }
}

#SUBNETS
resource "aws_subnet" "wrkstn-subnet-1"{
    vpc_id              = aws_vpc.wrkstn-vpc.id 
    cidr_block          = var.wrkstn_subnet_prefix[0]
    availability_zone   = "us-west-2a"

    tags = {
        Name = "wrkstn-subnet-1"
  }
}
resource "aws_subnet" "wrkstn-subnet-2"{
    vpc_id              = aws_vpc.wrkstn-vpc.id 
    cidr_block          = var.wrkstn_subnet_prefix[1]
    availability_zone   = "us-west-2b"

    tags = {
        Name = "wrkstn-subnet-2"
  }
}