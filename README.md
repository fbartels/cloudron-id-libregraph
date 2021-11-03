# Cloudron ID

A kind of toolbox app to manage and verify identities.

Contains:

- LibreGraph Connect as an OpenID Provider
- LibreGraph IDM as a simple LDAP server (will serve any ldif file)
- uses ghosttunnel (along with the Cloudron tls addon) expose ldap with trusted ssl certificates
- step-ca as a custom certificate authority for SSL and SSH (?)

## What it actually does

- Provides an OpenID Connect login provider that connects to the Cloudron user management
- Provides a minimal LDAP server to centrally manage LDAP for Cloudron and other applications

## Testing

```bash
ldapsearch -x -H ldaps://id.9wd.eu:7636 -b "dc=lg,dc=local" -D "cn=readonly,dc=lg,dc=local" -w 'readonly'
```

## Further links

Adding users: https://github.com/libregraph/idm#add-new-users-using-the-gen-newusers-command
Adding additional service users: https://github.com/libregraph/idm#adding-a-service-user-for-ldap-access
Migrate from OpenLDAP: https://github.com/libregraph/idm#replace-existing-openldap-with-idm