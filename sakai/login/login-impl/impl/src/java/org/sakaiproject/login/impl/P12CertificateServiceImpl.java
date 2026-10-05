/**
 * Copyright (c) 2003-2026 The Apereo Foundation
 *
 * Licensed under the Educational Community License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *             http://opensource.org/licenses/ecl2
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.sakaiproject.login.impl;

import java.io.ByteArrayInputStream;
import java.io.FileInputStream;
import java.io.InputStream;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.cert.CertPath;
import java.security.cert.CertPathValidator;
import java.security.cert.Certificate;
import java.security.cert.CertificateFactory;
import java.security.cert.PKIXParameters;
import java.security.cert.TrustAnchor;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Enumeration;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

import javax.security.auth.x500.X500Principal;

import lombok.Setter;
import lombok.extern.slf4j.Slf4j;

import org.apache.commons.lang3.StringUtils;

import org.sakaiproject.component.api.ServerConfigurationService;
import org.sakaiproject.login.api.P12AuthenticationException;
import org.sakaiproject.login.api.P12CertificateService;
import org.sakaiproject.user.api.User;
import org.sakaiproject.user.api.UserDirectoryService;
import org.sakaiproject.user.api.UserNotDefinedException;

@Slf4j
public class P12CertificateServiceImpl implements P12CertificateService {

	public static final String PROP_ENABLED = "login.p12.enabled";
	public static final String PROP_TRUSTSTORE_PATH = "login.p12.truststore.path";
	public static final String PROP_TRUSTSTORE_PASSWORD = "login.p12.truststore.password";
	public static final String PROP_IDENTITY_ATTRIBUTE = "login.p12.identity.attribute";

	@Setter
	private ServerConfigurationService serverConfigurationService;

	@Setter
	private UserDirectoryService userDirectoryService;

	@Override
	public boolean isEnabled() {
		return serverConfigurationService.getBoolean(PROP_ENABLED, false);
	}

	@Override
	public String authenticateToEid(byte[] p12Bytes, char[] passphrase) throws P12AuthenticationException {
		if (!isEnabled()) {
			throw new P12AuthenticationException("disabled", "PKCS#12 login is disabled");
		}
		if (p12Bytes == null || p12Bytes.length == 0) {
			throw new P12AuthenticationException("missing-file", "PKCS#12 file is required");
		}
		if (passphrase == null) {
			passphrase = new char[0];
		}

		try {
			KeyStore keyStore = KeyStore.getInstance("PKCS12");
			keyStore.load(new ByteArrayInputStream(p12Bytes), passphrase);

			String alias = findPrivateKeyAlias(keyStore, passphrase);
			if (alias == null) {
				throw new P12AuthenticationException("no-key", "PKCS#12 file has no private key entry");
			}

			Certificate[] chain = keyStore.getCertificateChain(alias);
			if (chain == null || chain.length == 0) {
				Certificate single = keyStore.getCertificate(alias);
				if (single == null) {
					throw new P12AuthenticationException("no-cert", "PKCS#12 file has no certificate");
				}
				chain = new Certificate[] { single };
			}

			X509Certificate endEntity = (X509Certificate) chain[0];
			verifyTrusted(endEntity, chain);

			String identity = extractIdentity(endEntity);
			if (StringUtils.isBlank(identity)) {
				throw new P12AuthenticationException("no-identity", "Could not read identity from certificate");
			}

			try {
				User user = userDirectoryService.getUserByEid(identity);
				return user.getEid();
			} catch (UserNotDefinedException e) {
				throw new P12AuthenticationException("unknown-user", "No Sakai user for certificate identity: " + identity);
			}
		} catch (P12AuthenticationException e) {
			throw e;
		} catch (java.io.IOException e) {
			throw new P12AuthenticationException("bad-passphrase", "Invalid PKCS#12 passphrase or file", e);
		} catch (Exception e) {
			log.warn("PKCS#12 authentication failed: {}", e.toString());
			throw new P12AuthenticationException("invalid", "PKCS#12 authentication failed", e);
		}
	}

	private String findPrivateKeyAlias(KeyStore keyStore, char[] passphrase) throws Exception {
		Enumeration<String> aliases = keyStore.aliases();
		while (aliases.hasMoreElements()) {
			String alias = aliases.nextElement();
			if (keyStore.isKeyEntry(alias)) {
				PrivateKey key = (PrivateKey) keyStore.getKey(alias, passphrase);
				if (key != null) {
					return alias;
				}
			}
		}
		return null;
	}

	private void verifyTrusted(X509Certificate endEntity, Certificate[] chain) throws P12AuthenticationException {
		String truststorePath = serverConfigurationService.getString(PROP_TRUSTSTORE_PATH, "");
		String truststorePassword = serverConfigurationService.getString(PROP_TRUSTSTORE_PASSWORD, "changeit");
		if (StringUtils.isBlank(truststorePath)) {
			throw new P12AuthenticationException("no-truststore", "login.p12.truststore.path is not configured");
		}

		try {
			KeyStore trustStore = KeyStore.getInstance(KeyStore.getDefaultType());
			try (InputStream in = new FileInputStream(truststorePath)) {
				trustStore.load(in, truststorePassword.toCharArray());
			}

			Set<TrustAnchor> anchors = new HashSet<>();
			Enumeration<String> aliases = trustStore.aliases();
			while (aliases.hasMoreElements()) {
				String alias = aliases.nextElement();
				Certificate cert = trustStore.getCertificate(alias);
				if (cert instanceof X509Certificate) {
					anchors.add(new TrustAnchor((X509Certificate) cert, null));
				}
			}
			if (anchors.isEmpty()) {
				throw new P12AuthenticationException("empty-truststore", "Truststore has no trusted certificates");
			}

			List<Certificate> certPathList = new ArrayList<>();
			for (Certificate c : chain) {
				if (c instanceof X509Certificate) {
					certPathList.add(c);
				}
			}
			CertificateFactory cf = CertificateFactory.getInstance("X.509");
			CertPath certPath = cf.generateCertPath(certPathList);

			PKIXParameters params = new PKIXParameters(anchors);
			params.setRevocationEnabled(false);
			CertPathValidator.getInstance("PKIX").validate(certPath, params);

			endEntity.checkValidity();
		} catch (P12AuthenticationException e) {
			throw e;
		} catch (Exception e) {
			throw new P12AuthenticationException("untrusted", "Certificate is not trusted or not valid", e);
		}
	}

	private String extractIdentity(X509Certificate cert) {
		String attribute = StringUtils.defaultIfBlank(
				serverConfigurationService.getString(PROP_IDENTITY_ATTRIBUTE, "cn"), "cn").toLowerCase(Locale.ROOT);

		if ("email".equals(attribute)) {
			String email = extractSanEmail(cert);
			if (StringUtils.isNotBlank(email)) {
				return email.trim();
			}
			return extractDnEmail(cert.getSubjectX500Principal());
		}

		return extractCn(cert.getSubjectX500Principal());
	}

	private String extractCn(X500Principal principal) {
		String dn = principal.getName();
		for (String part : dn.split(",")) {
			String trimmed = part.trim();
			if (trimmed.regionMatches(true, 0, "CN=", 0, 3)) {
				return trimmed.substring(3).trim();
			}
		}
		return null;
	}

	private String extractDnEmail(X500Principal principal) {
		String dn = principal.getName();
		for (String part : dn.split(",")) {
			String trimmed = part.trim();
			if (trimmed.regionMatches(true, 0, "EMAILADDRESS=", 0, 13)) {
				return trimmed.substring(13).trim();
			}
		}
		return null;
	}

	private String extractSanEmail(X509Certificate cert) {
		try {
			Collection<List<?>> sans = cert.getSubjectAlternativeNames();
			if (sans == null) {
				return null;
			}
			for (List<?> item : sans) {
				if (item == null || item.size() < 2) {
					continue;
				}
				Object type = item.get(0);
				Object value = item.get(1);
				// RFC 5280: rfc822Name = 1
				if (Integer.valueOf(1).equals(type) && value instanceof String) {
					return (String) value;
				}
			}
		} catch (Exception e) {
			log.debug("Could not read SAN email: {}", e.toString());
		}
		return null;
	}
}
