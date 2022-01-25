# Dehydrated-ovh

A Dehydrated ovh hook written in BASH

## Description

This is a OVH hook for [Dehydrated](https://github.com/dehydrated-io/dehydrated), the ACME client. It allows Dehydrated to automatically create  DNS records to respond to the ACME dns-01 challenges and therefore allows you to automatize HTTPS certificates management including [LetsEncrypt CA](https://letsencrypt.org/) wildcard certificates. It was formally created to be used in Desiccant, a Dehydrated automation engine but can be use standalone.

## Dependencies

- cURL
- sed
- dig
- nslookup

## OVH Credentials

Just copy `ovh-credentials-example` to` ovh-credentials` in that project's directory and replace the endpoint and credentials with your own.

```ini
dns_ovh_endpoint           = ovh-eu
dns_ovh_application_key    = YOUR_OVH_APPLICATION_KEY
dns_ovh_application_secret = YOUR_OVH_SECRET_KEY
dns_ovh_consumer_key       = YOUR_OVH_CONSUMER_KEY
```

You can ether keep this file in this project's directory, it will be ignored from versioning or export the DESICCANT_HOOK_CREDENTIALS environment variable that contain the path to the file before executing the dehydrated command.

If you do not yet have your OVH API credentials, you can create them using the official [OVH credentials page](https://eu.api.ovh.com/createToken/?GET=/domain/zone/*&POST=/domain/zone/*&DELETE=/domain/zone/*). 
