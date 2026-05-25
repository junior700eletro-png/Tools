
const interactionAPI = {
  click: (selector) => {
    document.querySelector(selector)?.click();
  },
  
  typeMessage: async (text) => {
    const input = document.querySelector('[data-message-input]');
    input.focus();
    input.value = text;
    input.dispatchEvent(new Event('input', { bubbles: true }));
    document.querySelector('[data-send-button]')?.click();
  },
  
  activateIntegration: (integrationName) => {
    const integration = Array.from(document.querySelectorAll('[data-integration-item]'))
      .find(el => el.getAttribute('data-name') === integrationName);
    integration?.click();
  },
  
  getIntegrations: () => {
    return Array.from(document.querySelectorAll('[data-integration-item]'))
      .map(el => ({
        name: el.getAttribute('data-name'),
        status: el.getAttribute('data-status'),
        description: el.textContent
      }));
  }
};

window.adapta = interactionAPI;