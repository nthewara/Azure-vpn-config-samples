<?xml version="1.0" encoding="utf-16"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text"/>
  <xsl:template match="/"># Microsoft Corporation
# Windows Azure Virtual Network

# This configuration template applies to Juniper J Series Services Router running JunOS 10.4.
# It configures an IPSec VPN tunnel connecting your on-premise VPN device with the Azure gateway.

# ---------------------------------------------------------------------------------------------------------------------
# Internet Key Exchange (IKE) configuration
# 
# This section specifies the authentication, encryption, hashing, and lifetime parameters for the Phase 1 negotiation
# and the main mode security association. We also specify the IP address of the peer of your on-premise VPN device 
# (which is the Azure Gateway) here.
set security ike proposal <xsl:value-of select="/Data/RP_IkeProposal"/> authentication-method pre-shared-keys
set security ike proposal <xsl:value-of select="/Data/RP_IkeProposal"/> authentication-algorithm sha1
set security ike proposal <xsl:value-of select="/Data/RP_IkeProposal"/> encryption-algorithm aes-256-cbc
set security ike proposal <xsl:value-of select="/Data/RP_IkeProposal"/> lifetime-seconds 28800
set security ike proposal <xsl:value-of select="/Data/RP_IkeProposal"/> dh-group group2
set security ike policy <xsl:value-of select="/Data/RP_IkePolicy"/> mode main
set security ike policy <xsl:value-of select="/Data/RP_IkePolicy"/> proposals <xsl:value-of select="/Data/RP_IkeProposal"/>
set security ike policy <xsl:value-of select="/Data/RP_IkePolicy"/> pre-shared-key ascii-text <xsl:value-of select="/Data/SP_PresharedKey"/>
set security ike gateway <xsl:value-of select="/Data/RP_IkeGateway"/> ike-policy <xsl:value-of select="/Data/RP_IkePolicy"/>
set security ike gateway <xsl:value-of select="/Data/RP_IkeGateway"/> address <xsl:value-of select="/Data/SP_AzureGatewayIpAddress"/>
set security ike gateway <xsl:value-of select="/Data/RP_IkeGateway"/> external-interface <xsl:value-of select="/Data/NameOfYourOutsideInterface"/>

# ---------------------------------------------------------------------------------------------------------------------
# IPSec configuration
# 
# This section specifies encryption, authentication, and lifetime properties for the Phase 2 negotiation and the quick
# mode security association.
set security ipsec proposal <xsl:value-of select="/Data/RP_IPSecProposal"/> protocol esp
set security ipsec proposal <xsl:value-of select="/Data/RP_IPSecProposal"/> authentication-algorithm hmac-sha1-96
set security ipsec proposal <xsl:value-of select="/Data/RP_IPSecProposal"/> encryption-algorithm aes-256-cbc
set security ipsec proposal <xsl:value-of select="/Data/RP_IPSecProposal"/> lifetime-seconds 3600
set security ipsec policy <xsl:value-of select="/Data/RP_IPSecPolicy"/> proposals <xsl:value-of select="/Data/RP_IPSecProposal"/>
set security ipsec vpn <xsl:value-of select="/Data/RP_IPSecVpn"/> ike gateway <xsl:value-of select="/Data/RP_IkeGateway"/>
set security ipsec vpn <xsl:value-of select="/Data/RP_IPSecVpn"/> ike ipsec-policy <xsl:value-of select="/Data/RP_IPSecPolicy"/>

# ---------------------------------------------------------------------------------------------------------------------
# ACL rules
# 
# Proper ACL rules are needed for permitting cross-premise network traffic.
# You should also allow inbound UDP/ESP traffic for the interface which will be used for the IPSec tunnel.
set security zones security-zone trust interfaces <xsl:value-of select="/Data/NameOfYourInsideInterface"/>
set security zones security-zone trust host-inbound-traffic system-services ike<xsl:for-each select="/Data/OnPremiseSubnets/Subnet">
set security zones security-zone trust address-book address <xsl:value-of select="/Data/RP_OnPremiseNetwork"/>-<xsl:number value="position()"/><xsl:text> </xsl:text><xsl:value-of select="SP_NetworkCIDR"/>
</xsl:for-each>

set security zones security-zone untrust interfaces <xsl:value-of select="/Data/NameOfYourOutsideInterface"/>
set security zones security-zone untrust host-inbound-traffic system-services ike
# you may need the following line if you have interface specific host-inbound-traffic rule
# because that will overwrite the zone specific rule
# set security zones security-zone untrust interface ge-0/0/0 host-inbound-traffic system-services ike<xsl:for-each select="/Data/VnetSubnets/Subnet">
set security zones security-zone trust address-book address <xsl:value-of select="/Data/RP_AzureNetwork"/>-<xsl:number value="position()"/><xsl:text> </xsl:text><xsl:value-of select="SP_NetworkCIDR"/>
</xsl:for-each>

# ---------------------------------------------------------------------------------------------------------------------
# This section binds the above-defined IPSec VPN policy to the cross-premise network traffic so that such traffic will be
# properly encrypted and transmitted via the IPSec VPN tunnel.
edit security policies from-zone trust to-zone untrust
set policy <xsl:value-of select="/Data/RP_TrustToUntrustPolicy"/> match source-address <xsl:value-of select="/Data/RP_OnPremiseNetwork"/>
set policy <xsl:value-of select="/Data/RP_TrustToUntrustPolicy"/> match destination-address <xsl:value-of select="/Data/RP_AzureNetwork"/>
set policy <xsl:value-of select="/Data/RP_TrustToUntrustPolicy"/> match application any
set policy <xsl:value-of select="/Data/RP_TrustToUntrustPolicy"/> then permit tunnel ipsec-vpn <xsl:value-of select="/Data/RP_IPSecVpn"/>
set policy <xsl:value-of select="/Data/RP_TrustToUntrustPolicy"/> then permit tunnel pair-policy <xsl:value-of select="/Data/RP_UntrustToTrustPolicy"/>
exit

edit security policies from-zone untrust to-zone trust
set policy <xsl:value-of select="/Data/RP_UntrustToTrustPolicy"/> match source-address <xsl:value-of select="/Data/RP_AzureNetwork"/>
set policy <xsl:value-of select="/Data/RP_UntrustToTrustPolicy"/> match destination-address <xsl:value-of select="/Data/RP_OnPremiseNetwork"/>
set policy <xsl:value-of select="/Data/RP_UntrustToTrustPolicy"/> match application any
set policy <xsl:value-of select="/Data/RP_UntrustToTrustPolicy"/> then permit tunnel ipsec-vpn <xsl:value-of select="/Data/RP_IPSecVpn"/>
set policy <xsl:value-of select="/Data/RP_UntrustToTrustPolicy"/> then permit tunnel pair-policy <xsl:value-of select="/Data/RP_TrustToUntrustPolicy"/>
exit

edit security policies from-zone trust to-zone untrust
insert policy <xsl:value-of select="/Data/RP_TrustToUntrustPolicy"/> before policy <xsl:value-of select="/Data/NameOfYourDefaultTrustToUntrustPolicy"/>
exit

# ---------------------------------------------------------------------------------------------------------------------
# TCPMSS clamping
#
# Adjust the TCPMSS value properly to avoid fragmentation
set security flow tcp-mss ipsec-vpn mss 1350

commit
exit
</xsl:template>
</xsl:stylesheet>
