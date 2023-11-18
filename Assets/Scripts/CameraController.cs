using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public class CameraController : MonoBehaviour
{
    private Vector2 movementDir;
    private bool MouseButtonDown;
    
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
        if (ctx.performed && MouseButtonDown)
        {
            Vector2 mouseDelta = ctx.ReadValue<Vector2>();
            transform.Rotate(new Vector3(0, mouseDelta.x * 0.1f, 0), Space.World);
            transform.Rotate(new Vector3(-mouseDelta.y * 0.1f, 0, 0), Space.Self);
        }
    }

    public void OnMouseButtonDown(InputAction.CallbackContext ctx)
    {
        if (ctx.started)
        {
            MouseButtonDown = true;
        }

        if (ctx.canceled)
        {
            MouseButtonDown = false;
        }
    }
}