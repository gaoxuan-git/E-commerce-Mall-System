const HIDDEN_VENDOR_COMPONENTS = new Set([
  '/operation/onePassConfig',
  '/operation/systemSms/pay',
  '/appSetting/publicRoutine/download',
]);

export function filterVendorMenus(items = []) {
  return items.flatMap((item) => {
    if (HIDDEN_VENDOR_COMPONENTS.has(item.component)) {
      return [];
    }

    const next = { ...item };
    const hadNestedChildren =
      (Array.isArray(item.childList) && item.childList.length > 0) ||
      (Array.isArray(item.children) && item.children.length > 0);

    if (Array.isArray(item.childList)) {
      next.childList = filterVendorMenus(item.childList);
    }
    if (Array.isArray(item.children)) {
      next.children = filterVendorMenus(item.children);
    }

    const hasNestedChildren =
      (Array.isArray(next.childList) && next.childList.length > 0) ||
      (Array.isArray(next.children) && next.children.length > 0);

    return hadNestedChildren && !hasNestedChildren ? [] : [next];
  });
}
