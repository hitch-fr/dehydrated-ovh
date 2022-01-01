# Dehydrated-ovh

A Dehydrated ovh hook written in BASH

## Description

This is a OVH hook for [Dehydrated](https://github.com/dehydrated-io/dehydrated), the ACME client. It allows Dehydrated to automatically create  DNS records to respond to the ACME dns-01 challenges and therefore allows you to automatize HTTPS certificates management including wildcard certificates. It was formally created to be used in Desiccant, a Dehydrated automation engine but can be use standalone.

## Dependencies

- cURL
- sed
- dig
- nslookup
