%%%
title = "OAuth 2.0 Rich Authorization Requests"
abbrev = "oauth-rar"
ipr = "trust200902"
area = "Security"
workgroup = "Web Authorization Protocol"
keyword = ["security", "oauth2"]

[seriesInfo]
name = "Internet-Draft"
value = "draft-lodderstedt-oauth-rar-03"
stream = "IETF"
status = "standard"

[[author]]
initials="T."
surname="Lodderstedt"
fullname="Torsten Lodderstedt"
organization="yes.com"
    [author.address]
    email = "torsten@lodderstedt.net"

[[author]]
initials="J."
surname="Richer"
fullname="Justin Richer"
organization="Bespoke Engineering"
    [author.address]
    email = "ietf@justin.richer.org"
    
[[author]]
initials="B."
surname="Campbell"
fullname="Brian Campbell"
organization="Ping Identity"
    [author.address]
    email = "bcampbell@pingidentity.com"
        
    
%%%

.# Abstract 

This document specifies a new parameter `authorization_details` that is 
used to carry fine grained authorization data in the OAuth authorization 
request. 

{mainmatter}

# Introduction {#Introduction}

The OAuth 2.0 authorization framework [@!RFC6749] defines the parameter `scope` that allows OAuth clients to
specify the requested scope, i.e., the permission, of an access token.
This mechanism is sufficient to implement static scenarios and
coarse-grained authorization requests, such as "give me read access to
the resource owner's profile" but it is not sufficient to specify
fine-grained authorization requirements, such as "please let me make a
payment with the amount of 45 Euros" or "please give me read access to
folder A and write access to file X".

This draft introduces a new parameter `authorization_details` that allows clients to specify their fine-grained authorization requirements using the expressiveness of JSON data structures. 

For example, a request for payment authorization can be represented using a JSON object like this:

```JSON
{
   "type": "payment_initiation",
   "locations": [
      "https://example.com/payments"
   ],
   "instructedAmount": {
      "currency": "EUR",
      "amount": "123.50"
   },
   "creditorName": "Merchant123",
   "creditorAccount": {
      "iban": "DE02100100109307118603"
   },
   "remittanceInformationUnstructured": "Ref Number Merchant"
}
```

This object contains detailed information about the intended payment, such as amount, currency, and creditor, that are required to inform the user and obtain her consent. The AS and the respective RS (providing the payment initation API) will together enforce this consent.

For a comprehensive discussion of the challenges arising from new use cases in the open banking and electronic signing spaces see [@transaction-authorization]. 

In addition to facilitating custom authorization requests, this draft also introduces a set of common data type fields for use across different APIs. 

Most notably, the field `locations` allows a client to specify where it intends to use a certain authorization, i.e., it is now possible to unambiguously assign permissions to resource servers. In situations with multiple resource servers, this prevents unintended client authorizations (e.g. a `read` scope value potentially applicable for an email as well as a cloud service). In combination with the `resource` token request parameter as specified in [@I-D.ietf-oauth-resource-indicators] it enables the AS to mint RS-specific structured access tokens that only contain the permissions applicable to the respective RS.

## Conventions and Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL
NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED",
"MAY", and "OPTIONAL" in this document are to be interpreted as
described in BCP 14 [@!RFC2119] [@!RFC8174] when, and only when, they
appear in all capitals, as shown here.

This specification uses the terms "access token", "refresh token",
"authorization server", "resource server", "authorization endpoint",
"authorization request", "authorization response", "token endpoint",
"grant type", "access token request", "access token response", and
"client" defined by The OAuth 2.0 Authorization Framework [@!RFC6749].

# Request parameter "authorization_details" {#authz_details}

The request parameter `authorization_details` contains, in JSON notation, an array of objects. Each JSON object contains the data to specify the authorization requirements for a certain type of resource. The type of resource or access requirement is determined by the `type` field. 

This example shows the specification of authorization details using the payment authorization object shown above: 

```JSON
[
   {
      "type": "payment_initiation",
      "actions": [
         "initiate",
         "status",
         "cancel"
      ],
      "locations": [
         "https://example.com/payments"
      ],
      "instructedAmount": {
         "currency": "EUR",
         "amount": "123.50"
      },
      "creditorName": "Merchant123",
      "creditorAccount": {
         "iban": "DE02100100109307118603"
      },
      "remittanceInformationUnstructured": "Ref Number Merchant"
   }
]
```

This example shows a combined request asking for access to account information and permission to initiate a payment:

```JSON
[
   {
      "type": "account_information",
      "actions": [
         "list_accounts",
         "read_balances",
         "read_transactions"
      ],
      "locations": [
         "https://example.com/accounts"
      ]
   },
   {
      "type": "payment_initiation",
      "actions": [
         "initiate",
         "status",
         "cancel"
      ],
      "locations": [
         "https://example.com/payments"
      ],
      "instructedAmount": {
         "currency": "EUR",
         "amount": "123.50"
      },
      "creditorName": "Merchant123",
      "creditorAccount": {
         "iban": "DE02100100109307118603"
      },
      "remittanceInformationUnstructured": "Ref Number Merchant"
   }
]
```

The JSON objects with `type` fields of `account_information` and `payment_initiation` represent the different authorization data to be used by the AS to ask for consent and MUST subsequently also be made available to the respective resource servers. The array MAY contain several elements of the same `type`. 

## Authorization data elements types

This draft defines a set of common data elements that are designed to be usable across different types of APIs. These data elements MAY be combined in different ways depending on the needs of the API. Unless otherwise noted, all data elements are OPTIONAL.

type:
:   The type of resource request as a string. This field MAY define which other elements are allowed in the request. This element is REQUIRED.

locations:
:   An array of strings representing the location of the resource or resource server. This is typically composed of URIs.

actions:
:   An array of strings representing the kinds of actions to be taken at the resource. The values of the strings are determined by the API being protected.

data:
:   An array of strings representing the kinds of data being requested from the resource. 

identifier:
:   A string identifier indicating a specific resource available at the API. 

An API MAY define its own extensions, subject to the `type` of the request. It is assumed that the full structure of each of the authorization data elements is tailored to the needs of a certain application, API, or resource type. The example structures shown above are based on certain kinds of APIs that can be found in the Open Banking space. 

Note: Applications MUST ensure that their authorization data types do not collide. This is either achieved by using a namespace under the control of the entity defining the type name or by registering the type with the new `OAuth Authorization Data Type Registry` (see (#iana_considerations)). 

The following example shows how an implementation could utilize the namespace `https://scheme.example.org/` to ensure collision resistant element names.

```JSON
{
   "type": "https://scheme.example.org/files",
   "locations": [
      "https://example.com/files"
   ],
   "permissions": [
      {
         "path": "/myfiles/A",
         "access": [
            "read"
         ]
      },
      {
         "path": "/myfiles/A/X",
         "access": [
            "read",
            "write"
         ]
      }
   ]
}
```
## Relationship to "scope" parameter {#scope}

`authorization_details` and `scope` can be used in the same authorization request for carrying independent authorization requirements. 

The AS MUST keep both requirements sets separate when reflecting this data to the client and passing this data through to resource servers.

For user convenience, the AS is supposed to merge the requirements when asking the user for consent.

### Scope value "openid" and "claims" parameter

OpenID Connect [@OIDC] specifies the JSON-based `claims` request parameter that can be used to specify the claims a client (acting as OpenID Connect Relying Party) wishes to receive in a fine-grained and privacy preserving way as well as assign those claims to a certain delivery mechanisms, i.e. ID Token or userinfo response. 

The combination of the scope value `openid` and the additional parameter `claims` can be used beside `authorization_details` in the same way as every other scope value and, potentially, further parameter providing additional data for the respective scope to the authorization process. 

Alternatively, there could be an authorization data type for OpenID Connect. (#openid) gives an example of how such an authorization data type could look like.

## Relationship to "resource" parameter

The request parameter `resource` as defined in [@I-D.ietf-oauth-resource-indicators] indicates to the AS the resource(s) where the client intends to use the access tokens issued based on a certain grant. This mechanism is a way to audience-restrict access tokens and to allow the AS to create resource server specific access tokens. 

If a client uses `authorization_details` with `locations` elements and the `resource` parameter in the same authorization request, the `locations` data take precedence over the data conveyed in the `resource` parameter for that particular authorization details object.

If such a client uses the `resource` parameter in a subsequent token requests, the AS MUST utilize the data provided in the `locations` elements to filter the authorization data objects applicable to the respective resource server. The AS will select all authorization details object where the `resource` string matches as prefix of one of the URLs provided in the respective `locations` element.

This shall be illustrated using an example. 

The client has sent an authorization request using the following example authorization details. 

```JSON
[
   {
      "type": "account_information",
      "actions": [
         "list_accounts",
         "read_balances",
         "read_transactions"
      ],
      "locations": [
         "https://example.com/accounts"
      ]
   },
   {
      "type": "payment_initiation",
      "actions": [
         "initiate",
         "status",
         "cancel"
      ],
      "locations": [
         "https://example.com/payments"
      ],
      "instructedAmount": {
         "currency": "EUR",
         "amount": "123.50"
      },
      "creditorName": "Merchant123",
      "creditorAccount": {
         "iban": "DE02100100109307118603"
      },
      "remittanceInformationUnstructured": "Ref Number Merchant"
   }
]
```

If this client then sends the following token request to the AS, 

```http
POST /token HTTP/1.1
Host: as.example.com
Authorization: Basic czZCaGRSa3F0MzpnWDFmQmF0M2JW
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&code=SplxlOBeZQQYbYS6WxSbIA
&redirect_uri=https%3A%2F%2Fclient%2Eexample%2Ecom%2Fcb
&resource=https%3A%2F%2Fexample%2Ecom%2Fpayments
```

that contains a resource parameter with the value of `https://example.com/payments`, this value will be matched against the locations elements (`https://example.com/accounts` and  `https://example.com/payments`) and will select the element 
of type "payment_initiation" for inclusion in the access token. 

```JSON
[
   {
      "type": "payment_initiation",
      "actions": [
         "initiate",
         "status",
         "cancel"
      ],
      "locations": [
         "https://example.com/payments"
      ],
      "instructedAmount": {
         "currency": "EUR",
         "amount": "123.50"
      },
      "creditorName": "Merchant123",
      "creditorAccount": {
         "iban": "DE02100100109307118603"
      },
      "remittanceInformationUnstructured": "Ref Number Merchant"
   }
]
```

# Using "authorization_details"

## Authorization Request

The request parameter can be used to specify authorization requirements in all places where the `scope` parameter is used for the same purpose, examples include:  

* Authorization requests as specified in [@!RFC6749], 
* Access token requests as specified in [@!RFC6749], if also used as authorization requests, e.g. in the case of assertion grant types [@!RFC7521],
* Request objects as specified in [@I-D.ietf-oauth-jwsreq], 
* Device Authorization Request as specified in [@!RFC8628],
* Backchannel Authentication Requests as defined in [@OpenID.CIBA].

Parameter encoding is determined by the respective context. 

In the context of an authorization request according to [@!RFC6749], the parameter is encoded using the `application/x-www-form-urlencoded` format as shown in the following example:

```
GET /authorize?response_type=code
   &client_id=s6BhdRkqt3
   &state=af0ifjsldkj
   &redirect_uri=https%3A%2F%2Fclient.example.org%2Fcb
   &code_challenge_method=S256
   &code_challenge=K2-ltc83acc4h0c9w6ESC_rEMTJ3bww-uCHaoeK1t8U
   &authorization_details=%5B%7B%22type%22%3A%22account%5Finformati
   on%22%2C%22actions%22%3A%5B%22list%5Faccounts%22%2C%22read%5Fbal
   ances%22%2C%22read%5Ftransactions%22%5D%2C%22locations%22%3A%5B%
   22https%3A%2F%2Fexample%2Ecom%2Faccounts%22%5D%7D%5D HTTP/1.1
Host: server.example.com
``` 

Implementors MUST ensure to protect personal identifiable information
in transit. One way is to utilize encrypted request objects as defined
in [@I-D.ietf-oauth-jwsreq]. In the context of a request object, 
`authorization_details` is added as another top level JSON element.

```JSON
{
   "iss": "s6BhdRkqt3",
   "aud": "https://server.example.com",
   "response_type": "code",
   "client_id": "s6BhdRkqt3",
   "redirect_uri": "https://client.example.com/cb",
   "state": "af0ifjsldkj",
   "code_challenge_method": "S256",
   "code_challenge": "K2-ltc83acc4h0c9w6ESC_rEMTJ3bww-uCHaoeK1t8U",
   "authorization_details": [
      {
         "type": "account_information",
         "actions": [
            "list_accounts",
            "read_balances",
            "read_transactions"
         ],
         "locations": [
            "https://example.com/accounts"
         ]
      },
      {
         "type": "payment_initiation",
         "actions": [
            "initiate",
            "status",
            "cancel"
         ],
         "locations": [
            "https://example.com/payments"
         ],
         "instructedAmount": {
            "currency": "EUR",
            "amount": "123.50"
         },
         "creditorName": "Merchant123",
         "creditorAccount": {
            "iban": "DE02100100109307118603"
         },
         "remittanceInformationUnstructured": "Ref Number Merchant"
      }
   ]
}
```

Authorization request URIs containing authorization details in a request parameter or a request object can become very long. Implementers SHOULD therefore consider using the `request_uri` parameter as defined in [@I-D.ietf-oauth-jwsreq] in combination with the pushed request object mechanism as defined in [@I-D.lodderstedt-oauth-par] to pass authorization details in a reliable and secure manner. Here is an example of such a pushed authorization request that sends the authorization request data directly to the AS via a HTTPS-protected connection: 

```
  POST /as/par HTTP/1.1
  Host: as.example.com
  Content-Type: application/x-www-form-urlencoded
  Authorization: Basic czZCaGRSa3F0Mzo3RmpmcDBaQnIxS3REUmJuZlZkbUl3

  response_type=code&
  client_id=s6BhdRkqt3
  &state=af0ifjsldkj
  &redirect_uri=https%3A%2F%2Fclient.example.org%2Fcb 
  &code_challenge_method=S256
  &code_challenge=K2-ltc83acc4h0c9w6ESC_rEMTJ3bww-uCHaoeK1t8U
  &authorization_details=%7B%22iss%22%3A%22s6BhdRkqt3%22%2C%22aud%22%
  3A%22https%3A%2F%2Fserver%2Eexample%2Ecom%22%2C%22response%5Ftype%2
  2%3A%22code%22%2C%22client%5Fid%22%3A%22s6BhdRkqt3%22%2C%22redirect
  %5Furi%22%3A%22https%3A%2F%2Fclient%2Eexample%2Ecom%2Fcb%22%2C%22st
  ate%22%3A%22af0ifjsldkj%22%2C%22code%5Fchallenge%5Fmethod%22%3A%22S
  256%22%2C%22code%5Fchallenge%22%3A%22K2%2Dltc83acc4h0c9w6ESC%5FrEMT
  J3bww%2DuCHaoeK1t8U%22%2C%22authorization%5Fdetails%22%3A%5B%7B%22t
  ype%22%3A%22account%5Finformation%22%2C%22actions%22%3A%5B%22list%5
  Faccounts%22%2C%22read%5Fbalances%22%2C%22read%5Ftransactions%22%5D
  %2C%22locations%22%3A%5B%22https%3A%2F%2Fexample%2Ecom%2Faccounts%2
  2%5D%7D%2C%7B%22type%22%3A%22payment%5Finitiation%22%2C%22actions%2
  2%3A%5B%22initiate%22%2C%22status%22%2C%22cancel%22%5D%2C%22locatio
  ns%22%3A%5B%22https%3A%2F%2Fexample%2Ecom%2Fpayments%22%5D%2C%22ins
  tructedAmount%22%3A%7B%22currency%22%3A%22EUR%22%2C%22amount%22%3A%
  22123%2E50%22%7D%2C%22creditorName%22%3A%22Merchant123%22%2C%22cred
  itorAccount%22%3A%7B%22iban%22%3A%22DE02100100109307118603%22%7D%2C
  %22remittanceInformationUnstructured%22%3A%22Ref%20Number%20Merchan
  t%22%7D%5D%7D
```

## Authorization Request Processing

Based on the data provided in the `authorization_details` parameter the AS will ask the user for consent to the requested access permissions. 

The AS MUST refuse to process any unknown authorization data type. If the `authorization_details` contain any unknown authorization data type, the AS MUST abort processing and respond with an error `invalid_authorization_details` to the client.

Note: If the authorization request also contained the `scope` parameter, the AS MUST also ask for user consent for the scope values.  

If the resource owner grants the client the requested access, the AS will issue tokens to the client that are associated with the respective `authorization_details` (and scope values, if applicable).

Note: The AS MUST make the `authorization_details` available to the respective resource servers. The AS MAY add the `authorization_details` element to access tokens in JWT format and to Token Introspection responses (see below). 

## Token Request

Clients utilizing authorization details are RECOMMENDED to use the `resource` token request parameter to allow the AS issue audience restricted access tokens. 

For example the following token request selects authorization details applicable for the resource server represented by the URI `https://example.com/payments`.

```http
POST /token HTTP/1.1
Host: as.example.com
Authorization: Basic czZCaGRSa3F0MzpnWDFmQmF0M2JW
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&code=SplxlOBeZQQYbYS6WxSbIA
&redirect_uri=https%3A%2F%2Fclient%2Eexample%2Ecom%2Fcb
&resource=https%3A%2F%2Fexample%2Ecom%2Fpayments
```

## Token Response
In addition to the token response parameters as defined in [@!RFC6749], the authorization server MUST also return the authorization details as granted by the resource owner and assigned to the respective access token. 

This is shown in the following example:

```JSON
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: no-cache, no-store

{
   "access_token": "2YotnFZFEjr1zCsicMWpAA",
   "token_type": "example",
   "expires_in": 3600,
   "refresh_token": "tGzv3JOkF0XG5Qx2TlKWIA",
   "authorization_details": [
      {
         "type": "https://www.someorg.com/payment_initiation",
         "actions": [
            "initiate",
            "status",
            "cancel"
         ],
         "locations": [
            "https://example.com/payments"
         ],
         "instructedAmount": {
            "currency": "EUR",
            "amount": "123.50"
         },
         "creditorName": "Merchant123",
         "creditorAccount": {
            "iban": "DE02100100109307118603"
         },
         "remittanceInformationUnstructured": "Ref Number Merchant"
      }
   ]
}
```

### Token Content {#token_content}

In order to enable the RS to enforce the authorization details as approved in the authorization process, the AS MUST make this data available to the RS. 

If the access token is a JWT [@!RFC7519], the AS is RECOMMENDED to add the `authorization_details` object, filtered to the specific audience, as top-level claim. 

The AS will typically also add further claims to the JWT the RS requires for request processing, e.g., user id, roles, and transaction specific data. What claims the particular RS requires is defined by the RS-specific policy with the AS.

The following shows the contents of an example JWT for the payment initation example above: 

```JSON
{
   "iss": "https://as.example.com",
   "sub": "24400320",
   "aud": "a7AfcPcsl2",
   "exp": 1311281970,
   "acr": "psd2_sca",
   "txn": "8b4729cc-32e4-4370-8cf0-5796154d1296",
   "authorization_details": [
      {
         "type": "https://www.someorg.com/payment_initiation",
         "actions": [
            "initiate",
            "status",
            "cancel"
         ],
         "locations": [
            "https://example.com/payments"
         ],
         "instructedAmount": {
            "currency": "EUR",
            "amount": "123.50"
         },
         "creditorName": "Merchant123",
         "creditorAccount": {
            "iban": "DE02100100109307118603"
         },
         "remittanceInformationUnstructured": "Ref Number Merchant"
      }
   ],
   "debtorAccount": {
      "iban": "DE40100100103307118608",
      "user_role": "owner"
   }
}
```

In this case, the AS added the following example claims:

* `sub`: conveys the user on which behalf the client is asking for payment initation
* `txn`: transaction id used to trace the transaction across the services of provider `example.com`
* `debtorAccount`: API-specific element containing the debtor account. In the example, this account was not passed in the authorization details but selected by the user during the authorization process. The field `user_role` conveys the role the user has with respect to this particuar account. In this case, she is the owner. This data is used for access control at the payment API (the RS).

## Token Introspection Request

In case of opaque access tokens, the data provided to a certain RS is determined using the RS's identifier with the AS (see [@I-D.ietf-oauth-jwt-introspection-response], section 3). 

## Token Introspection Response

The token endpoint response provides the RS with the authorization details applicable to it as a top-level JSON element along with the claims the RS requires for request processing. 

Here is an example for the payment initation example RS:

```json
{
   "active": true,
   "sub": "24400320",
   "aud": "s6BhdRkqt3",
   "exp": 1311281970,
   "acr": "psd2_sca",
   "txn": "8b4729cc-32e4-4370-8cf0-5796154d1296",
   "authorization_details": [
      {
         "type": "https://www.someorg.com/payment_initiation",
         "actions": [
            "initiate",
            "status",
            "cancel"
         ],
         "locations": [
            "https://example.com/payments"
         ],
         "instructedAmount": {
            "currency": "EUR",
            "amount": "123.50"
         },
         "creditorName": "Merchant123",
         "creditorAccount": {
            "iban": "DE02100100109307118603"
         },
         "remittanceInformationUnstructured": "Ref Number Merchant"
      }
   ],
   "debtorAccount": {
      "iban": "DE40100100103307118608",
      "user_role": "owner"
   }
}
```

# Metadata

The AS advertises support for `authorization_details` using the metadata parameter `authorization_details_supported` of type boolean.

The authorization data types supported can be determined using the metadata parameter `authorization_data_types_supported`, which is an JSON array.

Clients announce the authorization data types they use in the new dynamic client registration parameter `authorization_data_types`.

The registration of new authorization data types with the AS is out of scope of this draft. 

# Implementation Considerations

The scheme and processing will vary significantly among different authorization data types. Any implementation of this draft is therefore supposed to allow the customization of the user consent and the handling of access token data. 

One option would be to have a mechanism allowing the registration of extension modules, each of them responsible for rendering the respective user consent and any transformation needed to provide the data needed to the resource server by way of structured access tokens or token introspection responses. 

# Security Considerations

Authorization details are sent through the user agent in case of an OAuth authorization request, which makes them vulnerable to modifications by the user. In order to ensure their integrity, the client SHOULD send authorization details in a signed request object as defined in [@I-D.ietf-oauth-jwsreq] or use the `request_uri` authorization request parameter as defined in [@I-D.ietf-oauth-jwsreq] to pass the URI of the request object to the authorization server.

# Privacy Considerations

Implementers MUST design and use authorization details in a privacy preserving manner. 

Any sensitive personal data included in authorization details MUST be prevented from leaking, e.g., through referrer headers. Implementation options include encrypted request objects as defined in [@I-D.ietf-oauth-jwsreq] or transmission of authorization details via end-to-end encrypted connections between client and authorization server by utilizing the `request_uri` authorization request parameter as defined in [@I-D.ietf-oauth-jwsreq].

Even if the request data are encrypted, an attacker could use the authorization server to learn the user data by injecting the encrypted request data into an authorization request on a device under his control and use the authorization server's user consent screens to show the (decrypted) user data in the clear. Implementations MUST consider this attacker vector and implement appropriate counter measures, e.g. by only showing portions of the data or, if possible, determing whether the assumed user context is still the same (after user authentication). 

The AS MUST take into consideration the privacy implications when sharing authorization details with the resource servers. The AS SHOULD share this data with the resource servers on a "need to know" basis.

# Acknowledgements {#Acknowledgements}
      
We would would like to thank Daniel Fett, Sebastian Ebling, Dave Tonge, Mike Jones, Nat Sakimura, and Rob Otto for their valuable feedback during the preparation of this draft.

We would also like to thank Daniel Fett, Dave Tonge, Travis Spencer, and Aaron Parecki for their valuable feedback to this draft.

# IANA Considerations {#iana_considerations}

TBD

* `authorization_details` as JWT claim
* `authorization_details_supported` and `authorization_data_types_supported` as metadata parameters
* `authorization_data_types` as dynamic client registration parameter
* establish authorization data type registry
* register type `openid_claims`

<reference anchor="OIDC" target="http://openid.net/specs/openid-connect-core-1_0.html">
  <front>
    <title>OpenID Connect Core 1.0 incorporating errata set 1</title>
    <author initials="N." surname="Sakimura" fullname="Nat Sakimura">
      <organization>NRI</organization>
    </author>
    <author initials="J." surname="Bradley" fullname="John Bradley">
      <organization>Ping Identity</organization>
    </author>
    <author initials="M." surname="Jones" fullname="Mike Jones">
      <organization>Microsoft</organization>
    </author>
    <author initials="B." surname="de Medeiros" fullname="Breno de Medeiros">
      <organization>Google</organization>
    </author>
    <author initials="C." surname="Mortimore" fullname="Chuck Mortimore">
      <organization>Salesforce</organization>
    </author>
   <date day="8" month="Nov" year="2014"/>
  </front>
</reference>

<reference anchor="transaction-authorization" target="https://medium.com/oauth-2/transaction-authorization-or-why-we-need-to-re-think-oauth-scopes-2326e2038948">
  <front>
    <title>Transaction Authorization or why we need to re-think OAuth scopes</title>
    <author initials="T." surname="Lodderstedt" fullname="Torsten Lodderstedt">
      <organization>yes.com</organization>
    </author>
   <date day="20" month="Apr" year="2019"/>
  </front>
</reference>

<reference anchor="ETSI" target="https://www.etsi.org/deliver/etsi_ts/119400_119499/119432/01.01.01_60/ts_119432v010101p.pdf">
  <front>
    <title>ETSI TS 119 432, Electronic Signatures and Infrastructures (ESI); Protocols for remote digital signature creation </title>
     <author fullname="ETSI">
	    <organization abbrev="ETSI">ETSI</organization>
	  </author>
   <date day="20" month="Mar" year="2019"/>
  </front>
</reference>

<reference anchor="CSC" target="https://cloudsignatureconsortium.org/wp-content/uploads/2019/07/CSC_API_V1_1.0.4.0.pdf">
  <front>
    <title>Architectures and protocols for remote signature applications</title>
    <author fullname="Cloud Signature Consortium">
	    <organization abbrev="CSC">Cloud Signature Consortium</organization>
	  </author>	
   <date day="01" month="Jun" year="2019"/>
  </front>
</reference>

<reference anchor="OpenID.CIBA"
           target="https://openid.net/specs/openid-client-initiated-backchannel-authentication-core-1_0.html">
        <front>
          <title abbrev="CIBA">OpenID Connect Client Initiated Backchannel Authentication Flow - Core 1.0</title>
          <author fullname="Gonzalo Fernandez Rodriguez" initials="G." surname="Fernandez">
            <organization abbrev="Telefonica">Telefonica I+D</organization>
          </author>
          <author fullname="Florian Walter" initials="F." surname="Walter">
            <organization abbrev="">Deutsche Telekom AG</organization>
          </author>
          <author fullname="Axel Nennker" initials="A." surname="Nennker">
            <organization abbrev="">Deutsche Telekom AG</organization>
          </author>
          <author fullname="Dave Tonge" initials="D." surname="Tonge">
            <organization abbrev="Moneyhub">Moneyhub</organization>
          </author>
          <author fullname="Brian Campbell" initials="B." surname="Campbell">
            <organization abbrev="Ping Identity">Ping Identity</organization>
          </author>
          <date day="16" month="January" year="2019"/>
        </front>
      </reference>

{backmatter}

# Additional Examples

## OpenID Connect {#openid}

This hypothetical examples tries to encapsulate all details specific to the OpenID Connect part of an authorization process into an authorization JSON object.

The top-level elements are based on the definitions given in [@OIDC]:

* `claim_sets`: names of predefined claim sets, replacement for respective scope values, such as `profile`
* `max_age`: Maximum Authentication Age 
* `acr_values`: array of ACR values
* `claims`: the `claims` JSON structure as defined in [@OIDC]

This is a simple request for some claim sets. 

```json
[
   {
      "type": "openid",
      "locations": [
         "https://op.example.com/userinfo"
      ],
      "claim_sets": [
         "email",
         "profile"
      ]
   }
]
```

Note: `locations` specifies the location of the userinfo endpoint since this is the only place where an access token is used by a client (RP) in OpenID Connect to obtain claims.

A more sophisticated example is shown in the following

```json
[
   {
      "type": "openid",
      "locations": [
         "https://op.example.com/userinfo"
      ],
      "max_age": 86400,
      "acr_values": "urn:mace:incommon:iap:silver",
      "claims": {
         "userinfo": {
            "given_name": {
               "essential": true
            },
            "nickname": null,
            "email": {
               "essential": true
            },
            "email_verified": {
               "essential": true
            },
            "picture": null,
            "http://example.info/claims/groups": null
         },
         "id_token": {
            "auth_time": {
               "essential": true
            }
         }
      }
   }
]
```

## Remote Electronic Signing {#signing}

The following example is based on the concept layed out for remote electronic signing in ETSI TS 119 432 [@ETSI] and the CSC API for remote signature creation [@CSC].

```json
[
   {
      "type": "sign",
      "locations": [
         "https://signing.example.com/signdoc"
      ],
      "credentialID": "60916d31-932e-4820-ba82-1fcead1c9ea3",
      "documentDigests": [
         {
            "hash": "sTOgwOm+474gFj0q0x1iSNspKqbcse4IeiqlDg/HWuI=",
            "label": "Credit Contract"
         },
         {
            "hash": "HZQzZmMAIWekfGH0/ZKW1nsdt0xg3H6bZYztgsMTLw0=",
            "label": "Contract Payment Protection Insurance"
         }
      ],
      "hashAlgorithmOID": "2.16.840.1.101.3.4.2.1"
   }
]
```

The top-level elements have the following meaning:

* `credentialID`: identifier of the certificate to be used for signing
* `documentDigests`: array containing the hash of every document to be signed (`hash` elements). Additionally, the corresponding `label` element identifies the respective document to the user, e.g. to be used in user consent.
* `hashAlgorithm`: algomrithm that was used to calculate the hash values. 

The AS is supposed to ask the user for consent for the creation of signatues for the documents listed in the structure. The client uses the access token issued as result of the process to call the sign doc endpoint at the respective signing service to actually create the signature. This access token is bound to the client, the user id and the hashes (and signature algorithm) as consented by the user.

## Access to Tax Data {#tax}

This example is inspired by an API allowing third parties to access citizen's tax declarations and statements, for example to determine their credit worthiness.

```json
[
    {
        "type": "tax_data",
        "locations": [
            "https://taxservice.govehub.no"
        ],
        "actions":"read_tax_statement",
        "periods": ["2018"],
        "duration_of_access": 30,
        "tax_payer_id": "23674185438934"
    }
]
```

The top-level elements have the following meaning:

* `periods`: determines the periods the client wants to access
* `duration_of_access`: how long does the client intend to access the data in days
* `tax_payer_id`: identifier of the tax payer (if known to the client)


# Document History

   [[ To be removed from the final specification ]]
   
   -03
   
   * Reworked examples to illustrate privacy preserving use of `authorization_details`
   * Added text on audience restriction
   * Added description of relationship between `scope` and `authorization_details`
   * Added text on token request & response and `authorization_details`
   * Added text on how authorization details are conveyed to RSs by JWTs or token endpoint response
   * Added description of relationship between `claims` and `authorization_details`
   * Added more example from different sectors
   
   -02
   
   * Added Security Considerations
   * Added Privacy Considerations
   * Added notes on URI size and authorization details
   * Added requirement to return the effective authorization details granted by the resource owner in the token response 
   * changed `authorization_details` structure from object to array
   * added Justin Richer & Brian Campbell as Co-Authors

   -00 / -01

   *  first draft
   

