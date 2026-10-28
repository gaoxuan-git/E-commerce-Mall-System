package com.zbkj.service.support;

import com.alibaba.fastjson.JSONArray;
import com.alibaba.fastjson.JSONObject;
import com.zbkj.common.constants.OnePassConstants;
import com.zbkj.common.exception.CrmebException;
import org.springframework.stereotype.Component;
import org.springframework.util.MultiValueMap;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.concurrent.atomic.AtomicLong;

@Component
public class OnePassDevMockResponseFactory {

    private static final String PRODUCT_IMAGE =
            "crmebimage/public/open-data/abo-curated-v2/8101-main.jpg";
    private static final String LABEL_IMAGE = createLabelImage();

    private final AtomicLong sequence = new AtomicLong(1000000000L);

    public JSONObject create(String url, MultiValueMap<String, Object> params) {
        String endpoint = endpoint(url);
        if (OnePassConstants.USER_LOGIN_URI.equals(endpoint)) {
            return login();
        }
        if (OnePassConstants.USER_INFO_URI.equals(endpoint)) {
            return accountInfo();
        }
        if (OnePassConstants.ONE_PASS_TEMP_LIST_URI.equals(endpoint)
                || OnePassConstants.ONE_PASS_APPLYS_LIST_URI.equals(endpoint)) {
            return smsTemplates();
        }
        if (OnePassConstants.ONE_PASS_API_EXPRESS_URI.equals(endpoint)) {
            return expressCompanies();
        }
        if (OnePassConstants.ONE_PASS_API_EXPRESS_TEMP_URI.equals(endpoint)) {
            return expressTemplates(queryValue(url, "com", "yunda"));
        }
        if (OnePassConstants.ONE_PASS_API_EXPRESS_DUMP_RECORD_URI.equals(endpoint)) {
            return dumpRecords(queryValue(url, "com", "yunda"));
        }
        if (OnePassConstants.ONE_PASS_API_EXPRESS_DUMP_URI.equals(endpoint)) {
            return expressLabel(params);
        }
        if (OnePassConstants.ONE_PASS_API_EXPRESS_QUEARY_URI.equals(endpoint)) {
            return logistics(params);
        }
        if (OnePassConstants.ONE_PASS_API_SHIPMENT_GET_KUAIDI_COMS_URI.equals(endpoint)) {
            return shipmentCompanies();
        }
        if (OnePassConstants.ONE_PASS_API_SHIPMENT_CREATE_ORDER_URI.equals(endpoint)) {
            return shipmentOrder();
        }
        if (OnePassConstants.ONE_PASS_API_COPY_GOODS_URI.equals(endpoint)) {
            return product();
        }
        if (isSimpleSuccessEndpoint(endpoint)) {
            return ok(new JSONObject());
        }
        throw new CrmebException("开发模拟未实现该接口: " + endpoint);
    }

    private JSONObject login() {
        JSONObject data = new JSONObject();
        data.put("access_token", "dev-mock-token");
        data.put("expires_in", System.currentTimeMillis() / 1000L + 86400L);
        return ok(data);
    }

    private JSONObject accountInfo() {
        JSONObject data = new JSONObject();
        data.put("account", "local-dev-mock");
        data.put("sms", capability(1, 9999, "本地测试"));
        data.put("dump", capability(1, 9999, null));
        data.put("copy", capability(1, 9999, null));
        data.put("query", capability(1, 9999, null));
        return ok(data);
    }

    private JSONObject capability(int open, int count, String sign) {
        JSONObject value = new JSONObject();
        value.put("open", open);
        value.put("num", count);
        if (sign != null) {
            value.put("sign", sign);
        }
        return value;
    }

    private JSONObject smsTemplates() {
        JSONArray rows = new JSONArray();
        rows.add(smsTemplate(100001, "本地验证码", 1, "验证码为：{code}，{time}分钟内有效"));
        rows.add(smsTemplate(100002, "本地订单通知", 2, "订单 {order_id} 状态已更新"));

        JSONObject data = new JSONObject();
        data.put("count", rows.size());
        data.put("data", rows);
        return ok(data);
    }

    private JSONObject smsTemplate(int id, String title, int type, String content) {
        JSONObject template = new JSONObject();
        template.put("id", id);
        template.put("temp_id", id);
        template.put("title", title);
        template.put("temp_type", type);
        template.put("content", content);
        template.put("status", 1);
        template.put("mark", "本地模拟数据");
        return template;
    }

    private JSONObject expressCompanies() {
        JSONArray rows = new JSONArray();
        rows.add(expressCompany("yunda", "韵达快递"));
        rows.add(expressCompany("yuantong", "圆通速递"));
        rows.add(expressCompany("shunfeng", "顺丰速运"));

        JSONObject data = new JSONObject();
        data.put("data", rows);
        data.put("total", rows.size());
        return ok(data);
    }

    private JSONObject expressCompany(String code, String name) {
        JSONObject company = new JSONObject();
        company.put("code", code);
        company.put("name", name);
        company.put("partner_id", 0);
        company.put("partner_key", 0);
        company.put("net", 0);
        return company;
    }

    private JSONObject expressTemplates(String companyCode) {
        JSONArray rows = new JSONArray();
        rows.add(expressTemplate(companyCode));

        JSONObject data = new JSONObject();
        data.put("count", rows.size());
        data.put("data", rows);
        return ok(data);
    }

    private JSONObject dumpRecords(String companyCode) {
        JSONObject template = expressTemplate(companyCode);
        template.put("status", 1);

        JSONArray rows = new JSONArray();
        rows.add(template);

        JSONObject data = new JSONObject();
        data.put("count", rows.size());
        data.put("data", rows);
        return ok(data);
    }

    private JSONObject expressTemplate(String companyCode) {
        String normalizedCode = normalizeCompanyCode(companyCode);
        JSONObject template = new JSONObject();
        template.put("temp_id", templateId(normalizedCode));
        template.put("title", "本地测试面单");
        template.put("pic", LABEL_IMAGE);
        template.put("com", normalizedCode);
        return template;
    }

    private JSONObject expressLabel(MultiValueMap<String, Object> params) {
        String trackingNumber = nextTrackingNumber();
        JSONObject data = new JSONObject();
        data.put("order_id", first(params, "order_id", "DEV-ORDER-" + sequence.get()));
        data.put("kuaidinum", trackingNumber);
        data.put("label", LABEL_IMAGE);
        return ok(data);
    }

    private JSONObject logistics(MultiValueMap<String, Object> params) {
        JSONArray content = new JSONArray();
        content.add(logisticsTrack("2026-10-24 10:00:00", "本地模拟快件已签收"));
        content.add(logisticsTrack("2026-10-24 09:30:00", "本地模拟快件派送中"));

        JSONObject data = new JSONObject();
        data.put("ischeck", "1");
        data.put("status", "3");
        data.put("com", first(params, "com", "yunda"));
        data.put("num", first(params, "num", nextTrackingNumber()));
        data.put("content", content);
        return ok(data);
    }

    private JSONObject logisticsTrack(String time, String status) {
        JSONObject track = new JSONObject();
        track.put("time", time);
        track.put("ftime", time);
        track.put("status", status);
        return track;
    }

    private JSONObject shipmentCompanies() {
        JSONArray companies = new JSONArray();
        companies.add(shipmentCompany("yunda", "韵达快递"));
        companies.add(shipmentCompany("yuantong", "圆通速递"));
        companies.add(shipmentCompany("shunfeng", "顺丰速运"));
        return ok(companies);
    }

    private JSONObject shipmentCompany(String code, String label) {
        JSONArray types = new JSONArray();
        types.add("标准快递");

        JSONArray templates = new JSONArray();
        templates.add(expressTemplate(code));

        JSONObject company = new JSONObject();
        company.put("id", code);
        company.put("label", label);
        company.put("value", code);
        company.put("types", types);
        company.put("list", templates);
        return company;
    }

    private JSONObject shipmentOrder() {
        long id = sequence.incrementAndGet();
        JSONObject data = new JSONObject();
        data.put("order_id", "DEV-ORDER-" + id);
        data.put("task_id", "DEV-TASK-" + id);
        data.put("kuaidinum", "DEV" + id);
        return ok(data);
    }

    private JSONObject product() {
        JSONArray details = new JSONArray();
        details.add("标准版");

        JSONObject item = new JSONObject();
        item.put("value", "规格");
        item.put("detail", details);
        JSONArray items = new JSONArray();
        items.add(item);

        JSONObject skuDetail = new JSONObject();
        skuDetail.put("规格", "标准版");
        JSONObject sku = new JSONObject();
        sku.put("value1", "标准版");
        sku.put("pic", PRODUCT_IMAGE);
        sku.put("detail", skuDetail);
        JSONArray skuValues = new JSONArray();
        skuValues.add(sku);
        JSONObject info = new JSONObject();
        info.put("value", skuValues);

        JSONObject data = new JSONObject();
        data.put("store_name", "开发模拟采集商品");
        data.put("store_info", "仅用于本地功能测试");
        data.put("image", PRODUCT_IMAGE);
        data.put("slider_image", PRODUCT_IMAGE);
        data.put("cost", new BigDecimal("10.00"));
        data.put("price", new BigDecimal("19.90"));
        data.put("ot_price", new BigDecimal("29.90"));
        data.put("unit_name", "件");
        data.put("description", "<p>开发模拟商品，不对应真实外部商品。</p>");
        data.put("items", items);
        data.put("info", info);
        return ok(data);
    }

    private boolean isSimpleSuccessEndpoint(String endpoint) {
        return OnePassConstants.ONE_PASS_API_SEND_URI.equals(endpoint)
                || OnePassConstants.ONE_PASS_TEMP_APPLY_URI.equals(endpoint)
                || OnePassConstants.ONE_PASS_SMS_MODIFY_URI.equals(endpoint)
                || OnePassConstants.ONE_PASS_SMS_OPEN_URI.equals(endpoint)
                || OnePassConstants.ONE_PASS_EXPRESS_OPEN_URI.equals(endpoint)
                || OnePassConstants.ONE_PASS_COPY_OPEN_URI.equals(endpoint)
                || OnePassConstants.ONE_PASS_API_SHIPMENT_CANCEL_ORDER_URI.equals(endpoint);
    }

    private String endpoint(String url) {
        if (url == null || !url.startsWith(OnePassConstants.ONE_PASS_API_URL)) {
            throw new CrmebException("开发模拟不接受非一号通地址");
        }
        String endpoint = url.substring(OnePassConstants.ONE_PASS_API_URL.length());
        int queryIndex = endpoint.indexOf('?');
        return queryIndex >= 0 ? endpoint.substring(0, queryIndex) : endpoint;
    }

    private String queryValue(String url, String key, String fallback) {
        int queryIndex = url.indexOf('?');
        if (queryIndex < 0 || queryIndex == url.length() - 1) {
            return fallback;
        }
        String[] pairs = url.substring(queryIndex + 1).split("&");
        for (String pair : pairs) {
            String[] entry = pair.split("=", 2);
            if (entry.length == 2 && key.equals(entry[0]) && !entry[1].isEmpty()) {
                return entry[1];
            }
        }
        return fallback;
    }

    private JSONObject ok(Object data) {
        JSONObject response = new JSONObject();
        response.put("status", 200);
        response.put("msg", "ok");
        response.put("data", data);
        return response;
    }

    private String first(MultiValueMap<String, Object> params, String key, String fallback) {
        if (params == null || params.getFirst(key) == null) {
            return fallback;
        }
        return String.valueOf(params.getFirst(key));
    }

    private String normalizeCompanyCode(String companyCode) {
        if ("yuantong".equals(companyCode) || "shunfeng".equals(companyCode)) {
            return companyCode;
        }
        return "yunda";
    }

    private String templateId(String companyCode) {
        return "DEV-" + companyCode.toUpperCase() + "-001";
    }

    private String nextTrackingNumber() {
        return "DEV" + sequence.incrementAndGet();
    }

    private static String createLabelImage() {
        String svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"600\" height=\"360\">"
                + "<rect width=\"600\" height=\"360\" fill=\"white\" stroke=\"black\" stroke-width=\"8\"/>"
                + "<text x=\"300\" y=\"150\" text-anchor=\"middle\" font-size=\"42\" "
                + "font-family=\"sans-serif\">DEV MOCK LABEL</text>"
                + "<text x=\"300\" y=\"225\" text-anchor=\"middle\" font-size=\"28\" "
                + "font-family=\"sans-serif\">NOT FOR SHIPPING</text>"
                + "</svg>";
        return "data:image/svg+xml;base64,"
                + Base64.getEncoder().encodeToString(svg.getBytes(StandardCharsets.UTF_8));
    }
}
