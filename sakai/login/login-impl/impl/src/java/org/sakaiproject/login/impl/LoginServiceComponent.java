/**********************************************************************************
 * $URL:  $
 * $Id:  $
 ***********************************************************************************
 *
 * Copyright (c) 2008 The Sakai Foundation.
 * 
 * Licensed under the Educational Community License, Version 1.0 (the "License"); 
 * you may not use this file except in compliance with the License. 
 * You may obtain a copy of the License at
 * 
 *      http://www.opensource.org/licenses/ecl1.php
 * 
 * Unless required by applicable law or agreed to in writing, software 
 * distributed under the License is distributed on an "AS IS" BASIS, 
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
 * See the License for the specific language governing permissions and 
 * limitations under the License.
 *
 **********************************************************************************/
package org.sakaiproject.login.impl;

import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import javax.security.auth.login.LoginException;
import javax.servlet.http.HttpServletRequest;

import org.sakaiproject.component.cover.ComponentManager;
import org.sakaiproject.component.api.ServerConfigurationService;
import org.sakaiproject.event.api.UsageSessionService;
import org.sakaiproject.login.api.Login;
import org.sakaiproject.login.api.LoginAdvisor;
import org.sakaiproject.login.api.LoginCredentials;
import org.sakaiproject.login.api.LoginRenderEngine;
import org.sakaiproject.login.api.LoginService;
import org.sakaiproject.loginhistory.api.LoginHistoryEntry;
import org.sakaiproject.loginhistory.api.LoginHistoryService;

import org.sakaiproject.user.api.Authentication;
import org.sakaiproject.user.api.AuthenticationException;
import org.sakaiproject.user.api.Evidence;
import org.sakaiproject.user.api.AuthenticationManager;
import org.sakaiproject.util.IdPwEvidence;


public abstract class LoginServiceComponent implements LoginService {

	protected abstract AuthenticationManager authenticationManager();
	protected abstract ServerConfigurationService serverConfigurationService();
	protected abstract UsageSessionService usageSessionService();
	
	private Map<String, LoginRenderEngine> renderEngines = new ConcurrentHashMap<String, LoginRenderEngine>();
	
	private LoginAdvisor loginAdvisor = null;
	
	public void addRenderEngine(String context, LoginRenderEngine vengine) {
		renderEngines.put(context, vengine);
	}

	public void authenticate(LoginCredentials credentials) throws LoginException {
		LoginAdvisor loginAdvisor = resolveLoginAdvisor();
		
		// Only bother checking login credentials and/or imposing a penalty when the protection level is set
		boolean isAdvisorEnabled = loginAdvisor != null && loginAdvisor.isAdvisorEnabled();
		
		String eid = credentials != null ? credentials.getIdentifier() : null;
		String remoteAddr = credentials != null ? credentials.getRemoteAddr() : null;
		String userAgent = null;
		if (credentials != null && credentials.getRequest() != null) {
			userAgent = credentials.getRequest().getHeader("user-agent");
		}

		// authenticate
		try
		{
			String pw = credentials.getPassword();
			
			boolean isEidEmpty = (eid == null) || (eid.length() == 0);
			boolean isPwEmpty = (pw == null) || (pw.length() == 0);

			if (isBlockedIdentifier(eid)) {
				recordPasswordHistory(eid, null, remoteAddr, userAgent, false, Login.EXCEPTION_SSO_REQUIRED);
				throw new LoginException(Login.EXCEPTION_SSO_REQUIRED);
			}
			
			if (isAdvisorEnabled) {
				if (!loginAdvisor.checkCredentials(credentials)) {
					recordPasswordHistory(eid, null, remoteAddr, userAgent, false, Login.EXCEPTION_INVALID_CREDENTIALS);
					throw new LoginException(Login.EXCEPTION_INVALID_CREDENTIALS);
				}
			}
			
			if (isEidEmpty || isPwEmpty)
			{
				throw new AuthenticationException("missing-fields");
			}
			
			// Do NOT trim the password, since many authentication systems allow whitespace.
			eid = eid.trim();

			Evidence e = new IdPwEvidence(eid, pw, credentials.getRemoteAddr());

			Authentication a = authenticationManager().authenticate(e);

			// login the user
			if (usageSessionService().login(a, credentials.getRequest()))
			{
				if (isAdvisorEnabled) 
					loginAdvisor.setSuccess(credentials);
				recordPasswordHistory(a.getEid(), a.getUid(), remoteAddr, userAgent, true, null);
			}
			else
			{
				if (isAdvisorEnabled) 
					loginAdvisor.setFailure(credentials);
				recordPasswordHistory(eid, null, remoteAddr, userAgent, false, Login.EXCEPTION_INVALID);
				throw new LoginException(Login.EXCEPTION_INVALID);
			}
		}
		catch (AuthenticationException ex)
		{
			if (ex.getMessage().equals("missing-fields")) {
				recordPasswordHistory(eid, null, remoteAddr, userAgent, false, Login.EXCEPTION_MISSING_CREDENTIALS);
				throw new LoginException(Login.EXCEPTION_MISSING_CREDENTIALS);
			}
			
			/**
			 * If the Authentication Exception Equals Disabled then 
			 * re throw the message to the top.
			 */
			if (ex.getMessage().equals(Login.EXCEPTION_DISABLED)) {
				recordPasswordHistory(eid, null, remoteAddr, userAgent, false, Login.EXCEPTION_DISABLED);
				throw new LoginException(Login.EXCEPTION_DISABLED);
			}
			
			boolean isPenaltyImposed = false;
			
			if (isAdvisorEnabled) {
				loginAdvisor.setFailure(credentials);
				isPenaltyImposed = !loginAdvisor.checkCredentials(credentials);
			} 
			
			if (isPenaltyImposed) {
				recordPasswordHistory(eid, null, remoteAddr, userAgent, false, Login.EXCEPTION_INVALID_WITH_PENALTY);
				throw new LoginException(Login.EXCEPTION_INVALID_WITH_PENALTY);
			} else {
				recordPasswordHistory(eid, null, remoteAddr, userAgent, false, Login.EXCEPTION_INVALID);
				throw new LoginException(Login.EXCEPTION_INVALID);
			}
		}
		
	}

	private void recordPasswordHistory(String eid, String userId, String ip, String userAgent, boolean success, String failReason) {
		try {
			LoginHistoryService historyService = (LoginHistoryService) ComponentManager.get(LoginHistoryService.class);
			if (historyService == null) {
				return;
			}
			LoginHistoryEntry entry = new LoginHistoryEntry();
			entry.setEid(eid);
			entry.setUserId(userId);
			entry.setIp(ip);
			entry.setUserAgent(userAgent);
			entry.setMethod(LoginHistoryEntry.METHOD_PASSWORD);
			entry.setSuccess(success);
			entry.setFailReason(failReason);
			historyService.record(entry);
		} catch (Exception e) {
			// Never block login on history failures
		}
	}
	
	public String getLoginAdvice(LoginCredentials credentials) {
		LoginAdvisor loginAdvisor = resolveLoginAdvisor();
		
		// Only bother checking login credentials and/or imposing a penalty when the protection level is set
		boolean isAdvisorEnabled = loginAdvisor != null && loginAdvisor.isAdvisorEnabled();
		
		if (isAdvisorEnabled) {
			return loginAdvisor.getLoginAdvice(credentials);
		}
		
		return "";
	}
	
	public LoginRenderEngine getRenderEngine(String context, HttpServletRequest request)
	{
		// at this point we ignore request but we might use ut to return more
		// than one render engine

		if (context == null || context.length() == 0)
		{
			context = Login.DEFAULT_LOGIN_CONTEXT;
		}

		return (LoginRenderEngine) renderEngines.get(context);
	}
	
	public boolean hasLoginAdvice() {
		LoginAdvisor loginAdvisor = resolveLoginAdvisor();
		
		return loginAdvisor != null && loginAdvisor.isAdvisorEnabled();
	}
	
	public void removeRenderEngine(String context, LoginRenderEngine vengine) {
		renderEngines.remove(context);
	}

	private LoginAdvisor resolveLoginAdvisor() {
		if (loginAdvisor == null) {
			loginAdvisor = (LoginAdvisor)ComponentManager.get(LoginAdvisor.class);
		}
		
		return loginAdvisor;
	}

	private boolean isBlockedIdentifier(String identifier) {
		if (identifier == null) {
			return false;
		}

		String normalizedIdentifier = identifier.trim().toLowerCase(Locale.ROOT);

		List<String> blockedIdentifiers = serverConfigurationService()
				.getStringList("login.local.blocked.identifiers", Collections.emptyList());

		return blockedIdentifiers.stream()
				.map(String::trim)
				.filter(s -> !s.isEmpty())
				.map(s -> s.toLowerCase(Locale.ROOT))
				.anyMatch(pattern -> matchesPattern(normalizedIdentifier, pattern));
	}

	private boolean matchesPattern(String identifier, String pattern) {
		if ("*".equals(pattern)) {
        	return false;
		}

		if (pattern.startsWith("*") && pattern.endsWith("*") && pattern.length() > 2) {
			return identifier.contains(pattern.substring(1, pattern.length() - 1));
		}

		if (pattern.startsWith("*")) {
			return identifier.endsWith(pattern.substring(1));
		}

		if (pattern.endsWith("*")) {
			return identifier.startsWith(pattern.substring(0, pattern.length() - 1));
		}

		return identifier.equals(pattern);
	}

}
