using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public class CameraController : MonoBehaviour
{
    private Vector2 movementDir;

    // Start is called before the first frame update
    void Start()
    {
        Cursor.lockState = CursorLockMode.Locked;
    }

    // Update is called once per frame
    void Update()
    {
        transform.Translate(Time.deltaTime * 10 * new Vector3(movementDir.x, 0, movementDir.y), Space.Self);
    }

    public void OnMove(InputAction.CallbackContext ctx)
    {
        movementDir = ctx.ReadValue<Vector2>();
    }

    public void OnMouseMove(InputAction.CallbackContext ctx)
    {
        if (ctx.performed)
        {
            Vector2 mouseDelta = ctx.ReadValue<Vector2>();
            transform.Rotate(new Vector3(0, mouseDelta.x * 0.1f, 0), Space.World);
            transform.Rotate(new Vector3(-mouseDelta.y * 0.1f, 0, 0), Space.Self);
        }
    }
}
