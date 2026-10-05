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
package org.sakaiproject.login.api;

/**
 * Authenticate a user from an uploaded PKCS#12 (.p12 / .pfx) keystore.
 */
public interface P12CertificateService {

	/**
	 * Validate the PKCS#12 bytes, map the certificate identity to a Sakai eid, and return that eid.
	 *
	 * @param p12Bytes PKCS#12 file contents
	 * @param passphrase keystore passphrase (may be empty)
	 * @return Sakai eid derived from the certificate
	 * @throws P12AuthenticationException when the file, passphrase, trust, or identity mapping fails
	 */
	String authenticateToEid(byte[] p12Bytes, char[] passphrase) throws P12AuthenticationException;

	/**
	 * @return true when login.p12.enabled is true
	 */
	boolean isEnabled();
}
