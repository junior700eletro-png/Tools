
const captureInterface = async () => {
  const chatWindow = document.querySelector('[data-chat-container]');
  const integrations = document.querySelector('[data-integrations-panel]');
  
  return {
    chatContent: chatWindow?.innerText || null,
    integrationsList: Array.from(integrations?.querySelectorAll('[data-integration-item]') || [])
      .map(el => ({
        name: el.getAttribute('data-name'),
        status: el.getAttribute('data-status'),
        icon: el.getAttribute('data-icon')
      })),
    timestamp: new Date().toISOString()
  };
};

const observer = new MutationObserver(async () => {
  const data = await captureInterface();
  console.log('Interface atualizada:', data);
});

observer.observe(document.body, { childList: true, subtree: true });