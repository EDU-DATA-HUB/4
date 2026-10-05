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
package org.sakaiproject.loginhistory.impl;

import java.util.Date;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;

import lombok.Setter;
import lombok.extern.slf4j.Slf4j;

import org.bson.Document;

import org.sakaiproject.component.api.ServerConfigurationService;
import org.sakaiproject.loginhistory.api.LoginHistoryEntry;
import org.sakaiproject.loginhistory.api.LoginHistoryService;

@Slf4j
public class MongoLoginHistoryService implements LoginHistoryService {

	public static final String PROP_ENABLED = "login.history.mongodb.enabled";
	public static final String PROP_URI = "login.history.mongodb.uri";
	public static final String PROP_DATABASE = "login.history.mongodb.database";
	public static final String PROP_COLLECTION = "login.history.mongodb.collection";

	@Setter
	private ServerConfigurationService serverConfigurationService;

	private volatile MongoClient mongoClient;

	public void init() {
		if (!isEnabled()) {
			log.info("Login history MongoDB writer is disabled");
			return;
		}
		try {
			String uri = serverConfigurationService.getString(PROP_URI, "mongodb://127.0.0.1:27017");
			mongoClient = MongoClients.create(uri);
			// Force a quick connectivity check without failing startup if Mongo is briefly down.
			mongoClient.getDatabase(getDatabaseName()).runCommand(new Document("ping", 1));
			log.info("Login history MongoDB connected: db={} collection={}", getDatabaseName(), getCollectionName());
		} catch (Exception e) {
			log.warn("Login history MongoDB not reachable at startup (login will continue): {}", e.toString());
			closeQuietly();
		}
	}

	public void destroy() {
		closeQuietly();
	}

	@Override
	public void record(LoginHistoryEntry entry) {
		if (entry == null || !isEnabled()) {
			return;
		}
		try {
			MongoCollection<Document> collection = collection();
			Document doc = new Document();
			Date ts = entry.getTimestamp() != null ? entry.getTimestamp() : new Date();
			doc.put("timestamp", ts);
			doc.put("eid", entry.getEid());
			doc.put("userId", entry.getUserId());
			doc.put("ip", entry.getIp());
			doc.put("method", entry.getMethod());
			doc.put("success", entry.isSuccess());
			doc.put("failReason", entry.getFailReason());
			doc.put("userAgent", entry.getUserAgent());
			collection.insertOne(doc);
		} catch (Exception e) {
			log.warn("Failed to write login history to MongoDB (login not blocked): {}", e.toString());
		}
	}

	private MongoCollection<Document> collection() {
		MongoClient client = mongoClient;
		if (client == null) {
			synchronized (this) {
				if (mongoClient == null) {
					String uri = serverConfigurationService.getString(PROP_URI, "mongodb://127.0.0.1:27017");
					mongoClient = MongoClients.create(uri);
				}
				client = mongoClient;
			}
		}
		MongoDatabase db = client.getDatabase(getDatabaseName());
		return db.getCollection(getCollectionName());
	}

	private boolean isEnabled() {
		return serverConfigurationService != null
				&& serverConfigurationService.getBoolean(PROP_ENABLED, false);
	}

	private String getDatabaseName() {
		return serverConfigurationService.getString(PROP_DATABASE, "sakai");
	}

	private String getCollectionName() {
		return serverConfigurationService.getString(PROP_COLLECTION, "login_history");
	}

	private void closeQuietly() {
		MongoClient client = mongoClient;
		mongoClient = null;
		if (client != null) {
			try {
				client.close();
			} catch (Exception e) {
				log.debug("Error closing MongoClient: {}", e.toString());
			}
		}
	}
}
